import XCTest
import AppKit
import PDFKit
import ImageIO
@testable import QuickConvertCore

final class CoreTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("QuickConvertTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }

    func testCategoryFilteringAndAliases() throws {
        func file(_ name: String) -> URL { folder.appendingPathComponent(name) }
        let all = Set(OutputFormat.allCases)
        XCTAssertEqual(FormatPolicy.targets(for: [file("one.WAV"), file("two.flac")], enabled: all), [.mp3, .m4a])
        XCTAssertEqual(FormatPolicy.targets(for: [file("one.wav"), file("two.png")], enabled: all), [])
        XCTAssertEqual(FormatPolicy.targets(for: [file("one.jpeg")], enabled: all), [.png, .webp, .pdf])
        XCTAssertEqual(FormatPolicy.targets(for: [file("one.docx")], enabled: [.pdf]), [.pdf])
        XCTAssertEqual(FormatPolicy.targets(for: [], enabled: all), [])
        XCTAssertEqual(FormatPolicy.targets(for: [URL(string: "https://example.com/a.png")!], enabled: all), [])
    }

    func testFinderMenuSurvivesReconstructedItemsWithoutRepresentedObjects() throws {
        for format in OutputFormat.allCases {
            let reconstructed = NSMenuItem(title: format.title, action: nil, keyEquivalent: "")
            reconstructed.tag = format.finderMenuTag
            XCTAssertNil(reconstructed.representedObject)
            XCTAssertEqual(OutputFormat(finderMenuTag: reconstructed.tag), format)
        }
        for invalid in [Int.min, -1, 0, OutputFormat.allCases.count + 1, Int.max] {
            XCTAssertNil(OutputFormat(finderMenuTag: invalid))
        }
    }

    func testRequestRoundTripWithSpecialCharactersAndRejectsMalformedURLs() throws {
        let files = [folder.appendingPathComponent("中文 # & ? % +.png"), folder.appendingPathComponent("line\nbreak.png")]
        let request = try ConversionRequest(files: files, target: .pdf)
        let decoded = try ConversionRequest(url: request.url)
        XCTAssertEqual(decoded.files, files)
        XCTAssertEqual(decoded.target, .pdf)
        for url in ["https://convert?to=pdf&file=/a.png", "quickconvert://convert?to=pdf&file=relative.png",
                    "quickconvert://convert?to=pdf&to=png&file=/a.png", "quickconvert://convert?to=pdf&file=/a.png&shell=whoami",
                    "quickconvert://convert?to=pdf&file=/a.png%00", "quickconvert://convert/path?to=pdf&file=/a.png"] {
            XCTAssertThrowsError(try ConversionRequest(url: URL(string: url)!))
        }
    }

    func testEmptyPreferencesPersistAndCategoriesAreIndependent() throws {
        let suite = "QuickConvertTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.enabledFormats(for: .image), [.jpg, .png, .webp, .pdf])
        preferences.setEnabled([], for: .image)
        XCTAssertEqual(Preferences(defaults: defaults).enabledFormats(for: .image), [])
        XCTAssertEqual(preferences.enabledFormats(for: .document), [.pdf])
    }

    func testConcurrentPublishNeverOverwritesExistingFilesOrSymlinks() throws {
        let source = folder.appendingPathComponent("report.txt")
        let existing = folder.appendingPathComponent("report.pdf")
        try Data("original".utf8).write(to: existing)
        let staged = (0..<12).map { folder.appendingPathComponent("staged\($0)") }
        for file in staged { try Data("new".utf8).write(to: file) }
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("report (1).pdf"), withDestinationURL: existing)
        DispatchQueue.concurrentPerform(iterations: 12) { index in
            do { _ = try OutputPublisher.publish(staged: staged[index], source: source, target: .pdf) }
            catch { XCTFail(error.localizedDescription) }
        }
        XCTAssertEqual(try String(contentsOf: existing), "original")
        for number in 2...13 {
            XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("report (\(number)).pdf")), "new")
        }
    }

    func testTextPaginationAndNoOverwrite() throws {
        let source = folder.appendingPathComponent("你好.txt")
        try String(repeating: "QuickConvert 中文文字測試\n", count: 200).write(to: source, atomically: true, encoding: .utf8)
        let engine = ConversionEngine(dependencies: .init())
        let first = try engine.convert(source, to: .pdf)
        let second = try engine.convert(source, to: .pdf)
        XCTAssertEqual(second.lastPathComponent, "你好 (1).pdf")
        let document = try XCTUnwrap(PDFDocument(url: first))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("QuickConvert") == true)
        XCTAssertTrue(try String(contentsOf: source).contains("中文"))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix(".quickconvert-") })
    }

    func testEmptyAndMarkdownPDFs() throws {
        for (name, contents) in [("empty.txt", ""), ("notes.md", "# Heading\n\n**Bold** and [local link](https://example.invalid/image.png)\n中文")] {
            let source = folder.appendingPathComponent(name)
            try contents.write(to: source, atomically: true, encoding: .utf8)
            let output = try ConversionEngine(dependencies: .init()).convert(source, to: .pdf)
            XCTAssertEqual(PDFDocument(url: output)?.pageCount, 1)
        }
    }

    func testImageJPEGPDFAndTransparency() throws {
        let source = try makePNG()
        let engine = ConversionEngine(dependencies: .init())
        let jpeg = try engine.convert(source, to: .jpg)
        let pdf = try engine.convert(source, to: .pdf)
        let image = try XCTUnwrap(CGImageSourceCreateWithURL(jpeg as CFURL, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
        XCTAssertEqual(decoded.width, 40)
        XCTAssertEqual(decoded.height, 20)
        XCTAssertEqual(PDFDocument(url: pdf)?.pageCount, 1)
    }

    func testMissingDependencyAndCorruptInputLeaveNoOutputs() throws {
        let source = folder.appendingPathComponent("bad.wav")
        try Data([1, 2, 3]).write(to: source)
        XCTAssertThrowsError(try ConversionEngine(dependencies: .init()).convert(source, to: .mp3))
        let image = folder.appendingPathComponent("bad.png")
        try Data([1, 2, 3]).write(to: image)
        XCTAssertThrowsError(try ConversionEngine().convert(image, to: .pdf))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)), ["bad.wav", "bad.png"])
    }

    func testDirectoryAndSymlinkInputsAreRejected() throws {
        let directory = folder.appendingPathComponent("directory.png")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        XCTAssertThrowsError(try ConversionEngine().convert(directory, to: .pdf))
        let image = try makePNG()
        let symlink = folder.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: image)
        XCTAssertThrowsError(try ConversionEngine().convert(symlink, to: .pdf))
    }

    func testProcessHandlesLargeDiagnosticsTimeoutCancellationAndNetworkDenial() throws {
        let runner = ProcessRunner(timeout: 5)
        // Test scripts are passed as arguments in tests only; production never invokes a shell.
        XCTAssertThrowsError(try runner.run(URL(fileURLWithPath: "/bin/sh"),
                                           arguments: ["-c", "yes diagnostic | head -c 200000; exit 7"], directory: folder)) { error in
            XCTAssertLessThan(error.localizedDescription.utf8.count, 9000)
            XCTAssertTrue(error.localizedDescription.contains("diagnostic"))
        }
        let start = Date()
        XCTAssertThrowsError(try ProcessRunner(timeout: 0.1).run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["20"], directory: folder)) { error in
            XCTAssertEqual(error.localizedDescription, ConversionError.timedOut.localizedDescription)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
        XCTAssertThrowsError(try runner.run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["20"], directory: folder, cancelled: { true }))
        XCTAssertThrowsError(try runner.run(URL(fileURLWithPath: "/usr/bin/perl"),
                                           arguments: ["-MSocket", "-e", "socket(S,PF_INET,SOCK_STREAM,0) or die \"socket errno=\".(0+$!); connect(S,sockaddr_in(9,inet_aton(\"127.0.0.1\"))) or die \"connect errno=\".(0+$!);"], directory: folder)) { error in
            // EPERM proves sandbox denial, rather than merely reaching an unused port (ECONNREFUSED).
            XCTAssertTrue(error.localizedDescription.contains("connect errno=1 "))
        }
    }

    func testFFmpegAudioMatrixAndWebPIntegration() throws {
        let tools = integrationDependencies()
        guard tools.ffmpeg != nil else { throw XCTSkip("FFmpeg not installed") }
        let engine = ConversionEngine(dependencies: tools)
        let wav = folder.appendingPathComponent("tone.wav")
        var pcm = Data()
        for sample in 0..<4410 {
            var value = Int16(sin(Double(sample) * 2 * .pi * 440 / 44100) * 10000).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        append(UInt32(36 + pcm.count)); data.append(Data("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(UInt32(44100)); append(UInt32(88200)); append(UInt16(2)); append(UInt16(16))
        data.append(Data("data".utf8)); append(UInt32(pcm.count)); data.append(pcm)
        try data.write(to: wav)
        for format: OutputFormat in [.mp3, .m4a, .flac] {
            let encoded = try engine.convert(wav, to: format)
            let decoded = try engine.convert(encoded, to: .wav)
            XCTAssertGreaterThan(try Data(contentsOf: decoded).count, 100)
        }
        let png = try makePNG()
        let webp = try engine.convert(png, to: .webp)
        XCTAssertNotNil(CGImageSourceCreateWithURL(webp as CFURL, nil))
        _ = try engine.convert(webp, to: .png)
    }

    func testBatchContinuesAfterFailureAndReportsProgress() async throws {
        let missing = folder.appendingPathComponent("missing.txt")
        let good = folder.appendingPathComponent("good.txt")
        try "good".write(to: good, atomically: true, encoding: .utf8)
        let request = try ConversionRequest(files: [missing, good], target: .pdf)
        let results = await BatchConverter.run(request)
        XCTAssertEqual(results.count, 2)
        XCTAssertNotNil(results[0].error)
        XCTAssertNotNil(results[1].output)
    }

    func testLibreOfficeDocumentMatrixIntegration() throws {
        let tools = integrationDependencies()
        guard tools.libreOffice != nil else { throw XCTSkip("LibreOffice not installed") }
        let engine = ConversionEngine(dependencies: tools)
        for (name, pages) in [("document.docx", 2), ("workbook.xlsx", 2), ("presentation.pptx", 2), ("page.html", 1)] {
            let bundled = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
            let source = folder.appendingPathComponent(name)
            try FileManager.default.copyItem(at: bundled, to: source)
            let output = try engine.convert(source, to: .pdf)
            let pdf = try XCTUnwrap(PDFDocument(url: output))
            XCTAssertEqual(pdf.pageCount, pages, name)
            XCTAssertTrue(pdf.string?.contains("QuickConvert") == true, name)
        }
    }

    func testMenuConstructionPerformance() {
        let files = (0..<500).map { folder.appendingPathComponent("\($0).png") }
        let start = Date()
        for _ in 0..<100 { _ = FormatPolicy.targets(for: files, enabled: Set(OutputFormat.allCases)) }
        XCTAssertLessThan(Date().timeIntervalSince(start) / 100, 0.5)
    }

    func testBundledToolsWinOverExternalTools() throws {
        let app = folder.appendingPathComponent("Quick Convert 中文.app")
        let ffmpeg = try fakeExecutable(app.appendingPathComponent("Contents/Helpers/ffmpeg"))
        let office = try fakeExecutable(app.appendingPathComponent("Contents/Helpers/LibreOffice-arm64.app/Contents/MacOS/soffice"))
        let external = folder.appendingPathComponent("external")
        for name in ["ffmpeg", "soffice", "cwebp"] { _ = try fakeExecutable(external.appendingPathComponent(name)) }
        let tools = Dependencies.discover(environment: ["PATH": external.path], bundleURL: app, architecture: "arm64")
        XCTAssertEqual(tools.ffmpeg, ffmpeg)
        XCTAssertEqual(tools.libreOffice, office)
        XCTAssertNil(tools.cwebp, "Use bundled FFmpeg for WebP instead of external cwebp")
        XCTAssertTrue(tools.isSelfContained)
    }

    func testBundledOnlyNeverFallsBackAndSelectsProcessArchitecture() throws {
        let app = folder.appendingPathComponent("QuickConvert.app")
        let office = try fakeExecutable(app.appendingPathComponent("Contents/Helpers/LibreOffice-x86_64.app/Contents/MacOS/soffice"))
        let external = folder.appendingPathComponent("external")
        _ = try fakeExecutable(external.appendingPathComponent("ffmpeg"))
        _ = try fakeExecutable(external.appendingPathComponent("soffice"))
        let arm = Dependencies.discover(environment: ["PATH": external.path], bundleURL: app,
                                        architecture: "arm64", policy: .bundledOnly)
        XCTAssertNil(arm.ffmpeg)
        XCTAssertNil(arm.libreOffice)
        XCTAssertFalse(arm.isSelfContained)
        let intel = Dependencies.discover(environment: [:], bundleURL: app, architecture: "x86_64", policy: .bundledOnly)
        XCTAssertEqual(intel.libreOffice, office)
    }

    func testBundledExecutableCannotBeAnEscapingSymlinkOrDirectory() throws {
        let app = folder.appendingPathComponent("QuickConvert.app")
        let helper = app.appendingPathComponent("Contents/Helpers/ffmpeg")
        let external = try fakeExecutable(folder.appendingPathComponent("outside"))
        try FileManager.default.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: helper, withDestinationURL: external)
        XCTAssertNil(Dependencies.discover(environment: [:], bundleURL: app, policy: .bundledOnly).ffmpeg)
        try FileManager.default.removeItem(at: helper)
        try FileManager.default.createDirectory(at: helper, withIntermediateDirectories: false)
        XCTAssertNil(Dependencies.discover(environment: [:], bundleURL: app, policy: .bundledOnly).ffmpeg)
    }

    private func fakeExecutable(_ path: URL) throws -> URL {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return path
    }

    private func integrationDependencies() -> Dependencies {
        if let app = ProcessInfo.processInfo.environment["QUICKCONVERT_TEST_BUNDLE"] {
            return Dependencies.discover(environment: [:], bundleURL: URL(fileURLWithPath: app), policy: .bundledOnly)
        }
        return .discover()
    }

    private func makePNG() throws -> URL {
        let context = try XCTUnwrap(CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        let source = folder.appendingPathComponent("image.png")
        let output = try XCTUnwrap(CGImageDestinationCreateWithURL(source as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(output, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(output))
        return source
    }
}
