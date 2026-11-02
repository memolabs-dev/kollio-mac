import Testing
@testable import KollioCore

@Suite("Accessible reading paths")
struct ReadingPathTests {
    @Test("CAN-10 AC01: a missing point is skipped and never remapped")
    func missingPointIsSkipped() throws {
        let existing = KollioID.object("sarah-csv")
        let missing = KollioID.object("deleted-point")
        let path = ReadingPath(points: [.object(missing), .object(existing)])

        let resolution = path.resolved(in: Fixture.sarah())

        #expect(resolution.requested == 2)
        #expect(resolution.entries.map(\.point) == [.object(existing)])
        #expect(resolution.skipped.map(\.point) == [.object(missing)])
    }

    @Test("CAN-10 AC01: the automatic path is deterministic")
    func automaticPathIsDeterministic() {
        let document = Fixture.sarah()
        #expect(ReadingPath.automatic(in: document) == ReadingPath.automatic(in: document))
    }
}
