import Foundation
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

enum NativeConverter {
    static func image(_ source: URL, to destination: URL, target: OutputFormat) throws {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any] else {
            throw ConversionError.invalidOutput
        }
        let maxDimension = max(properties[kCGImagePropertyPixelWidth] as? Int ?? 1,
                               properties[kCGImagePropertyPixelHeight] as? Int ?? 1)
        // Apply EXIF orientation instead of copying misleading orientation metadata.
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                      kCGImageSourceThumbnailMaxPixelSize: maxDimension]
        guard var image = CGImageSourceCreateThumbnailAtIndex(input, 0, options as CFDictionary) else {
            throw ConversionError.invalidOutput
        }
        if target == .pdf {
            var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            guard let context = CGContext(destination as CFURL, mediaBox: &box, nil) else {
                throw ConversionError.invalidOutput
            }
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(box)
            context.draw(image, in: box)
            context.endPDFPage()
            context.closePDF()
            return
        }
        if target == .jpg {
            guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw ConversionError.invalidOutput
            }
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            context.draw(image, in: bounds)
            guard let flattened = context.makeImage() else { throw ConversionError.invalidOutput }
            image = flattened
        }
        let type = target == .jpg ? UTType.jpeg.identifier : UTType.png.identifier
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, type as CFString, 1, nil) else {
            throw ConversionError.invalidOutput
        }
        CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw ConversionError.invalidOutput }
    }

    static func textPDF(_ source: URL, to destination: URL,
                        cancelled: @Sendable () -> Bool) throws {
        // Explicit UTF-8 avoids silently guessing an encoding and corrupting non-ASCII text.
        var text = try String(contentsOf: source, encoding: .utf8)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
        ]
        let content: NSAttributedString
        if source.pathExtension.lowercased() == "md" {
            let markdown = try AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            let styled = NSMutableAttributedString(markdown)
            styled.addAttributes(attributes, range: NSRange(location: 0, length: styled.length))
            content = styled
        } else {
            content = NSAttributedString(string: text, attributes: attributes)
        }
        var page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let context = CGContext(destination as CFURL, mediaBox: &page, nil) else {
            throw ConversionError.invalidOutput
        }
        defer { context.closePDF() }
        let framesetter = CTFramesetterCreateWithAttributedString(content)
        let path = CGPath(rect: page.insetBy(dx: 48, dy: 48), transform: nil)
        var offset = 0
        repeat {
            if cancelled() { throw ConversionError.cancelled }
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let range = CTFrameGetVisibleStringRange(frame)
            if content.length == 0 { break }
            guard range.length > 0 else { throw ConversionError.invalidOutput }
            offset += range.length
        } while offset < content.length
    }
}
