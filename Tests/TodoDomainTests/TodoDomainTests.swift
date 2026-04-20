import XCTest
@testable import TodoDomain

final class TodoDomainTests: XCTestCase {
    private let engine = TodoMutationEngine()

    func testParserRecognizesManagedSectionsAndChecklistItems() throws {
        let document = TodoDocument.parse(fixture("canonical/full"), filePath: "/tmp/2026-04-20 TODO.md")

        XCTAssertEqual(document.preambleLines, ["[[실행 허브]]", ""])
        XCTAssertEqual(document.sections.map(\.name), ["ROUTINE", "SLIT", "SPEC", "OTHERS"])
        XCTAssertEqual(document.checklistItems(in: "ROUTINE").map(\.text), ["Stretch", "Read notes"])
        XCTAssertEqual(document.checklistItems(in: "SLIT").first?.reference.occurrenceIndex, 0)
    }

    func testWriterPreservesPreambleUnknownSectionsAndPassthroughLines() throws {
        let input = fixture("unknown/with_unmanaged_sections")
        let document = TodoDocument.parse(input, filePath: "/tmp/2026-04-20 TODO.md")
        let target = try XCTUnwrap(document.checklistItems(in: "ROUTINE").first?.reference)

        let toggled = try engine.toggle(document: document, target: target)
        let rendered = toggled.render()

        XCTAssertTrue(rendered.contains("## PROJECTS\nAlpha\n"))
        XCTAssertTrue(rendered.contains("notes for routine"))
        XCTAssertTrue(rendered.contains("- [x] Stretch"))
        XCTAssertTrue(rendered.hasPrefix("[[실행 허브]]\n\n## PROJECTS"))
    }

    func testParserLeavesMalformedChecklistMarkersAsPassthrough() throws {
        let document = TodoDocument.parse(fixture("managed/malformed_checklists"), filePath: "/tmp/2026-04-20 TODO.md")
        let routineSection = try XCTUnwrap(document.sections.first(where: { $0.name == "ROUTINE" }))

        XCTAssertEqual(routineSection.checklistItems.map(\.text), ["Valid routine"])
        XCTAssertTrue(routineSection.lines.contains(.passthrough("- [] broken marker")))
        XCTAssertTrue(routineSection.lines.contains(.passthrough("- [maybe] not a checkbox")))
        XCTAssertTrue(routineSection.lines.contains(.passthrough("prefix - [ ] should stay passthrough")))
    }

    func testAddUsesLastUsedSectionAndFallsBackToOthers() throws {
        let document = TodoDocument.parse(fixture("managed/empty_sections"), filePath: "/tmp/2026-04-20 TODO.md")

        let lastUsedAdd = try engine.add(document: document, request: TodoAddRequest(text: "Ship parser", lastUsedSection: "SPEC"))
        XCTAssertEqual(lastUsedAdd.reference.sectionName, "SPEC")
        XCTAssertTrue(lastUsedAdd.document.render().contains("### SPEC\n- [ ] Ship parser"))

        let fallbackAdd = try engine.add(document: document, request: TodoAddRequest(text: "Inbox zero", lastUsedSection: nil))
        XCTAssertEqual(fallbackAdd.reference.sectionName, "OTHERS")
    }

    func testAddRejectsWhitespaceOnlyText() throws {
        let document = TodoDocument.parse(fixture("managed/empty_sections"), filePath: "/tmp/2026-04-20 TODO.md")

        XCTAssertThrowsError(try engine.add(document: document, request: TodoAddRequest(text: "   "))) { error in
            XCTAssertEqual(error as? TodoMutationError, .emptyText)
        }
    }

    func testAddCreatesMissingManagedSectionWithoutDisturbingUnknownSections() throws {
        let document = TodoDocument.parse(fixture("unknown/missing_managed_section"), filePath: "/tmp/2026-04-20 TODO.md")
        let result = try engine.add(document: document, request: TodoAddRequest(text: "Draft spec", preferredSection: "SPEC"))
        let rendered = result.document.render()

        XCTAssertTrue(rendered.contains("### SPEC\n- [ ] Draft spec"))
        XCTAssertTrue(rendered.contains("## BACKLOG\n- [ ] Someday maybe"))
        XCTAssertTrue(result.document.sections.map(\.name).contains("SPEC"))
    }

    func testToggleRejectsAmbiguousStaleReferenceAfterExternalReorder() throws {
        let original = TodoDocument.parse(fixture("ambiguity/duplicate_items"), filePath: "/tmp/2026-04-20 TODO.md")
        let target = original.checklistItems(in: "SLIT")[1].reference
        let reordered = TodoDocument.parse(fixture("ambiguity/duplicate_items_reordered"), filePath: "/tmp/2026-04-20 TODO.md")

        XCTAssertThrowsError(try engine.toggle(document: reordered, target: target)) { error in
            XCTAssertEqual(error as? TodoMutationError, .itemResolutionFailed(target))
        }
    }

    func testFileMutationServiceWritesAtomicallyAndUsesFreshParseOnStaleSnapshot() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let url = tempDirectory.appendingPathComponent("2026-04-20 TODO.md")
        try fixture("canonical/full").write(to: url, atomically: true, encoding: .utf8)

        let service = TodoFileMutationService()
        let initial = try service.loadDocument(at: url)
        let target = try XCTUnwrap(initial.document.checklistItems(in: "ROUTINE").first?.reference)

        let externallyEdited = fixture("preamble/external_edit_preserves_target")
        try externallyEdited.write(to: url, atomically: true, encoding: .utf8)

        let updated = try service.toggleItem(at: url, target: target, expectedFingerprint: initial.fingerprint)
        XCTAssertNotEqual(updated.fingerprint, initial.fingerprint)
        XCTAssertTrue(try String(contentsOf: url).contains("- [x] Stretch"))
    }

    func testFileMutationServiceAbortsWhenExternalEditMakesTargetAmbiguous() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let url = tempDirectory.appendingPathComponent("2026-04-20 TODO.md")
        try fixture("ambiguity/duplicate_items").write(to: url, atomically: true, encoding: .utf8)

        let service = TodoFileMutationService()
        let initial = try service.loadDocument(at: url)
        let target = initial.document.checklistItems(in: "SLIT")[1].reference

        try fixture("ambiguity/duplicate_items_reordered").write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try service.toggleItem(at: url, target: target, expectedFingerprint: initial.fingerprint)) { error in
            XCTAssertEqual(error as? TodoMutationError, .itemResolutionFailed(target))
        }
    }

    func testFileMutationServiceAddItemUsesFreshParseOnStaleSnapshot() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let url = tempDirectory.appendingPathComponent("2026-04-20 TODO.md")
        try fixture("canonical/full").write(to: url, atomically: true, encoding: .utf8)

        let service = TodoFileMutationService()
        let initial = try service.loadDocument(at: url)

        let externallyEdited = """
        [[실행 허브]]

        Edited from CLI before add

        ### ROUTINE
        - [ ] Stretch
        - [ ] Read notes

        ### SLIT
        - [ ] Ship menu bar shell

        ### SPEC
        - [x] Lock file contract

        ### OTHERS
        - [ ] Buy coffee
        """
        try externallyEdited.write(to: url, atomically: true, encoding: .utf8)

        let result = try service.addItem(
            at: url,
            request: TodoAddRequest(text: "Review worker acceptance evidence", lastUsedSection: "SPEC"),
            expectedFingerprint: initial.fingerprint
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("Edited from CLI before add"))
        XCTAssertTrue(text.contains("- [ ] Review worker acceptance evidence"))
        XCTAssertEqual(result.reference.sectionName, "SPEC")
    }

    private func fixture(_ name: String) -> String {
        let fileName = name.split(separator: "/").last.map(String.init) ?? name
        let resourceURL = Bundle.module.resourceURL!
        let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == "\(fileName).md" {
                return try! String(contentsOf: fileURL, encoding: .utf8)
            }
        }
        fatalError("Missing fixture: \(name).md")
    }
}
