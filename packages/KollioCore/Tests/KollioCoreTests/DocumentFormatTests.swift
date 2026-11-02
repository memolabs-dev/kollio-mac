import Foundation
import Testing
@testable import KollioCore

@Suite("Document format")
struct DocumentFormatTests {
    @Test("Round-trips through the portable JSON format")
    func roundTrip() throws {
        var document = Fixture.sarah()
        document.title = "Sarah launch plan"
        let data = try DocumentCodec.encode(document)
        let decoded = try DocumentCodec.decode(data)
        #expect(decoded == document)
    }

    @Test("A document written before titles existed keeps opening")
    func legacyDocumentWithoutTitle() throws {
        let data = try DocumentCodec.encode(Fixture.sarah())
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "title")

        let legacy = try JSONSerialization.data(withJSONObject: json)
        let decoded = try DocumentCodec.decode(legacy)

        #expect(decoded.title == "Kollio")
        #expect(decoded.content == Fixture.sarah().content)
    }

    @Test("Stores no renderer type and no platform type")
    func portability() throws {
        let data = try DocumentCodec.encode(Fixture.sarah())
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("CGPoint"))
        #expect(!json.contains("Color"))
        #expect(!json.contains("SwiftUI"))
        // Geometry is stored as plain {x,y} / {width,height} values.
        #expect(json.contains("\"x\""))
        #expect(json.contains("\"width\""))
    }

    @Test("Rejects a newer schema version instead of guessing")
    func futureSchema() throws {
        var document = Fixture.sarah()
        document.schemaVersion = KollioDocument.currentSchemaVersion + 1
        let data = try DocumentCodec.encode(document)
        #expect(throws: DocumentCodec.CodecError.self) {
            try DocumentCodec.decode(data)
        }
    }

    @Test("Keeps object identity stable across serialization")
    func stableIDs() throws {
        let document = Fixture.sarah()
        let decoded = try DocumentCodec.decode(try DocumentCodec.encode(document))
        #expect(Set(document.content.keys) == Set(decoded.content.keys))
        #expect(Set(document.relationships.keys) == Set(decoded.relationships.keys))
        #expect(Set(document.presentation.instances.map(\.objectID)) == Set(decoded.presentation.instances.map(\.objectID)))
    }

    /// CAN-04 added `objectVersion`. A file written before it existed has no such
    /// key, and that is a document that has never been edited concurrently rather
    /// than a corrupt one. It has to keep opening: the alternative is that adding
    /// a field makes every existing document unreadable.
    @Test("Reads a file written before objects had a version")
    func legacyObjectWithoutAVersion() throws {
        let data = try DocumentCodec.encode(Fixture.sarah())
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var content = json["content"] as! [String: Any]
        for (id, raw) in content {
            var object = raw as! [String: Any]
            object.removeValue(forKey: "objectVersion")
            content[id] = object
        }
        json["content"] = content

        let legacy = try JSONSerialization.data(withJSONObject: json)
        let decoded = try DocumentCodec.decode(legacy)

        #expect(decoded.content.count == Fixture.sarah().content.count)
        #expect(decoded.content.values.allSatisfy { $0.objectVersion == 0 })
        // And the text survived, which is the part that actually matters.
        #expect(decoded.content[ObjectID("object:sarah-crm")]?.text.text
                == Fixture.sarah().content[ObjectID("object:sarah-crm")]?.text.text)
    }

    @Test("A version that was written comes back the same")
    func versionRoundTrip() throws {
        var document = Fixture.sarah()
        let id = ObjectID("object:sarah-crm")
        document.content[id]?.objectVersion = 7
        let decoded = try DocumentCodec.decode(try DocumentCodec.encode(document))
        #expect(decoded.content[id]?.objectVersion == 7)
    }

    @Test("Derives three visual forms from the semantic kinds")
    func visualForms() {
        let object = ContentObject(id: "a", kind: .hypothesis, text: LocalizedText("x"), provenance: .human("me"))
        #expect(object.form == .thought)
        let product = ContentObject(id: "b", kind: .product, text: LocalizedText("x"), provenance: .human("me"))
        #expect(product.form == .richResult)
        let evidence = ContentObject(id: "c", kind: .evidence, text: LocalizedText("x"), provenance: .human("me"))
        #expect(evidence.form == .reference)
    }
}
