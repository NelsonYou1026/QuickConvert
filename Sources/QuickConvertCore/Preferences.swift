import Foundation

public final class Preferences {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults? = nil) {
        let group = Bundle.main.object(forInfoDictionaryKey: "QuickConvertAppGroup") as? String
        self.defaults = defaults ?? group.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func enabledFormats(for category: FileCategory) -> Set<OutputFormat> {
        guard let stored = defaults.stringArray(forKey: "formats.\(category.rawValue)") else {
            return Set(category.targets)
        }
        return Set(stored.compactMap(OutputFormat.init(rawValue:)))
    }

    public func setEnabled(_ formats: Set<OutputFormat>, for category: FileCategory) {
        defaults.set(formats.map(\.rawValue).sorted(), forKey: "formats.\(category.rawValue)")
    }
}
