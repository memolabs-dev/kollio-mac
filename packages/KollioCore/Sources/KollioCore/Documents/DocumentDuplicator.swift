import Foundation

/// Produces an editable document that shares no internal identity with its source.
///
/// The portable JSON representation is used as the traversal surface so newly
/// added ledgers participate automatically. Only values that are known internal
/// identifiers are rewritten; authored text, source locators and provenance are
/// deliberately left byte-for-byte unchanged.
public enum DocumentDuplicator {
    public enum DuplicationError: Error, Equatable {
        case invalidDocumentRepresentation
    }

    public static func duplicate(
        _ document: KollioDocument,
        documentID: String = UUID().uuidString,
        title: String? = nil
    ) throws -> KollioDocument {
        let encoded = try DocumentCodec.encode(document)
        let raw = try JSONSerialization.jsonObject(with: encoded)
        guard let object = raw as? [String: Any] else {
            throw DuplicationError.invalidDocumentRepresentation
        }

        var identifiers = Set<String>()
        collectIdentifiers(in: object, field: nil, into: &identifiers)
        let replacements = Dictionary(uniqueKeysWithValues: identifiers.map { id in
            (id, freshIdentifier(replacing: id))
        })
        guard var remapped = remap(object, field: nil, using: replacements) as? [String: Any] else {
            throw DuplicationError.invalidDocumentRepresentation
        }
        remapped["documentId"] = documentID
        if let title {
            remapped["title"] = title
        }
        let data = try JSONSerialization.data(withJSONObject: remapped, options: [.sortedKeys])
        return try DocumentCodec.decode(data)
    }

    private static let internalPrefixes: Set<String> = [
        "object", "relationship", "rel", "decision", "instance", "frame",
        "source", "revision", "rev", "citation", "claim", "clarification",
        "question", "comparison", "criterion", "cell", "summary", "section",
        "line", "sourceRef", "experiment", "result", "measurement", "history",
        "contribution", "impact", "scope", "finding"
    ]

    /// These fields carry the person's words or an external reference. A sentence
    /// that happens to equal `object:x` is still a sentence, not an identifier.
    private static let literalFields: Set<String> = [
        "text", "title", "name", "rationale", "reason", "quote", "observation",
        "locator", "digest", "unit", "summary", "outcome", "question", "answer"
    ]

    private static func isInternalIdentifier(_ value: String) -> Bool {
        guard let separator = value.firstIndex(of: ":") else { return false }
        return internalPrefixes.contains(String(value[..<separator]))
    }

    private static func collectIdentifiers(
        in value: Any,
        field: String?,
        into identifiers: inout Set<String>
    ) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if isInternalIdentifier(key) { identifiers.insert(key) }
                collectIdentifiers(in: child, field: key, into: &identifiers)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectIdentifiers(in: child, field: field, into: &identifiers)
            }
        } else if let string = value as? String,
                  literalFields.contains(field ?? "") == false,
                  isInternalIdentifier(string) {
            identifiers.insert(string)
        }
    }

    private static func remap(_ value: Any, field: String?, using replacements: [String: String]) -> Any {
        if let dictionary = value as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: dictionary.map { key, child in
                let remappedKey = replacements[key] ?? key
                return (remappedKey, remap(child, field: key, using: replacements))
            })
        }
        if let array = value as? [Any] {
            return array.map { remap($0, field: field, using: replacements) }
        }
        if let string = value as? String,
           literalFields.contains(field ?? "") == false {
            return replacements[string] ?? string
        }
        return value
    }

    private static func freshIdentifier(replacing identifier: String) -> String {
        let prefix = identifier.split(separator: ":", maxSplits: 1).first.map(String.init) ?? "id"
        return "\(prefix):\(UUID().uuidString.lowercased())"
    }
}
