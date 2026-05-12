struct XcodeVersionExtractor {

    func extractVersion(from filename: String) -> String? {
        var name = filename

        if let dotRange = name.range(of: ".xip", options: .backwards) {
            name = String(name[..<dotRange.lowerBound])
        } else if let dotRange = name.range(of: ".app", options: .backwards) {
            name = String(name[..<dotRange.lowerBound])
        } else {
            return nil
        }

        guard name.hasPrefix("Xcode") else { return nil }
        name = String(name.dropFirst("Xcode".count))

        if name.hasPrefix("_") || name.hasPrefix("-") || name.hasPrefix(" ") {
            name = String(name.dropFirst())
        }

        guard !name.isEmpty else { return nil }

        let normalized = name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")

        // Strip architecture suffixes (e.g., "-Apple-silicon", "-Universal")
        let architectureSuffixes = ["-Apple-silicon", "-Universal", "-arm64", "-x86-64"]
        var result = normalized
        for suffix in architectureSuffixes {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }

        // Trim trailing hyphens left over after stripping
        while result.hasSuffix("-") {
            result = String(result.dropLast())
        }

        return result.isEmpty ? nil : result
    }
}
