import Foundation

public struct TodoDocumentFingerprint: Equatable, Sendable {
    public let byteCount: Int
    public let contentHash: Int

    public init(contents: String) {
        let utf8 = Array(contents.utf8)
        self.byteCount = utf8.count
        self.contentHash = contents.hashValue
    }
}

public struct TodoItemReference: Equatable, Hashable, Sendable {
    public let filePath: String?
    public let sectionName: String
    public let occurrenceIndex: Int
    public let normalizedText: String
    public let isChecked: Bool

    public init(
        filePath: String?,
        sectionName: String,
        occurrenceIndex: Int,
        normalizedText: String,
        isChecked: Bool
    ) {
        self.filePath = filePath
        self.sectionName = sectionName
        self.occurrenceIndex = occurrenceIndex
        self.normalizedText = normalizedText
        self.isChecked = isChecked
    }
}

public struct TodoChecklistItem: Equatable, Sendable {
    public let reference: TodoItemReference
    public var text: String
    public var isChecked: Bool
    public let sourceLineIndex: Int

    public init(reference: TodoItemReference, text: String, isChecked: Bool, sourceLineIndex: Int) {
        self.reference = reference
        self.text = text
        self.isChecked = isChecked
        self.sourceLineIndex = sourceLineIndex
    }
}

public enum TodoSectionLine: Equatable, Sendable {
    case checklist(TodoChecklistItem)
    case passthrough(String)
}

public struct TodoSection: Equatable, Sendable {
    public var name: String
    public var headingLine: String
    public var lines: [TodoSectionLine]
    public var isManaged: Bool

    public init(name: String, headingLine: String, lines: [TodoSectionLine], isManaged: Bool) {
        self.name = name
        self.headingLine = headingLine
        self.lines = lines
        self.isManaged = isManaged
    }

    public var checklistItems: [TodoChecklistItem] {
        lines.compactMap {
            guard case let .checklist(item) = $0 else { return nil }
            return item
        }
    }
}

public struct TodoDocument: Equatable, Sendable {
    public var preambleLines: [String]
    public var sections: [TodoSection]
    public var managedSectionOrder: [String]
    public var newline: String
    public var hadTrailingNewline: Bool
    public var filePath: String?

    public init(
        preambleLines: [String],
        sections: [TodoSection],
        managedSectionOrder: [String],
        newline: String,
        hadTrailingNewline: Bool,
        filePath: String?
    ) {
        self.preambleLines = preambleLines
        self.sections = sections
        self.managedSectionOrder = managedSectionOrder
        self.newline = newline
        self.hadTrailingNewline = hadTrailingNewline
        self.filePath = filePath
    }

    public static let defaultManagedSectionOrder = ["ROUTINE", "SLIT", "SPEC", "OTHERS"]

    public static func parse(
        _ contents: String,
        filePath: String? = nil,
        managedSectionOrder: [String] = TodoDocument.defaultManagedSectionOrder
    ) -> TodoDocument {
        let newline = contents.contains("\r\n") ? "\r\n" : "\n"
        let hadTrailingNewline = contents.hasSuffix("\n") || contents.hasSuffix("\r\n")
        let sanitized = contents.replacingOccurrences(of: "\r\n", with: "\n")
        let rawLines = sanitized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let headingRegex = try! NSRegularExpression(pattern: "^###\\s+(.+?)\\s*$")
        let managedSet = Set(managedSectionOrder)

        var preambleLines: [String] = []
        var sections: [TodoSection] = []
        var currentSection: TodoSection?
        var occurrenceBySection: [String: Int] = [:]

        func parseChecklist(line: String, sectionName: String, lineIndex: Int) -> TodoChecklistItem? {
            guard let markerRange = line.range(of: "- [") else { return nil }
            let prefix = line[..<markerRange.lowerBound]
            guard prefix.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let suffix = line[markerRange.lowerBound...]
            guard suffix.hasPrefix("- [") else { return nil }
            guard line.count >= 6 else { return nil }
            let tokens = Array(line)
            guard tokens.count >= 6, tokens[0] == "-", tokens[1] == " ", tokens[2] == "[", tokens[4] == "]", tokens[5] == " " else {
                return nil
            }
            let state = String(tokens[3]).lowercased()
            guard state == " " || state == "x" else { return nil }
            let textStart = line.index(line.startIndex, offsetBy: 6)
            let text = String(line[textStart...])
            let occurrence = occurrenceBySection[sectionName, default: 0]
            occurrenceBySection[sectionName] = occurrence + 1
            let reference = TodoItemReference(
                filePath: filePath,
                sectionName: sectionName,
                occurrenceIndex: occurrence,
                normalizedText: Self.normalize(text: text),
                isChecked: state == "x"
            )
            return TodoChecklistItem(reference: reference, text: text, isChecked: state == "x", sourceLineIndex: lineIndex)
        }

        func flushSection() {
            guard let currentSection else { return }
            sections.append(currentSection)
        }

        for (lineIndex, line) in rawLines.enumerated() {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = headingRegex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                flushSection()
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                currentSection = TodoSection(
                    name: name,
                    headingLine: line,
                    lines: [],
                    isManaged: managedSet.contains(name)
                )
                continue
            }

            if currentSection == nil {
                preambleLines.append(line)
            } else if let item = parseChecklist(line: line, sectionName: currentSection!.name, lineIndex: lineIndex) {
                currentSection!.lines.append(.checklist(item))
            } else {
                currentSection!.lines.append(.passthrough(line))
            }
        }

        flushSection()

        return TodoDocument(
            preambleLines: preambleLines,
            sections: sections,
            managedSectionOrder: managedSectionOrder,
            newline: newline,
            hadTrailingNewline: hadTrailingNewline,
            filePath: filePath
        )
    }

    public static func normalize(text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    public func render() -> String {
        var renderedLines = preambleLines
        for section in sections {
            renderedLines.append(section.headingLine)
            for line in section.lines {
                switch line {
                case let .passthrough(raw):
                    renderedLines.append(raw)
                case let .checklist(item):
                    renderedLines.append("- [\(item.isChecked ? "x" : " ")] \(item.text)")
                }
            }
        }
        let joined = renderedLines.joined(separator: newline)
        if joined.isEmpty { return joined }
        return hadTrailingNewline ? joined + newline : joined
    }

    public var fingerprint: TodoDocumentFingerprint {
        TodoDocumentFingerprint(contents: render())
    }

    public func checklistItems(in sectionName: String) -> [TodoChecklistItem] {
        sections.first(where: { $0.name == sectionName })?.checklistItems ?? []
    }
}

public enum TodoMutationError: Error, Equatable, Sendable {
    case emptyText
    case sectionResolutionFailed(String)
    case itemResolutionFailed(TodoItemReference)
    case ambiguousItem(TodoItemReference)
    case staleSnapshot
}

public struct TodoAddRequest: Equatable, Sendable {
    public let text: String
    public let preferredSection: String?
    public let lastUsedSection: String?

    public init(text: String, preferredSection: String? = nil, lastUsedSection: String? = nil) {
        self.text = text
        self.preferredSection = preferredSection
        self.lastUsedSection = lastUsedSection
    }
}

public struct TodoMutationEngine: Sendable {
    public init() {}

    public func toggle(document: TodoDocument, target: TodoItemReference) throws -> TodoDocument {
        var document = document
        var matchedPaths: [(sectionIndex: Int, lineIndex: Int)] = []

        for (sectionIndex, section) in document.sections.enumerated() where section.name == target.sectionName {
            for (lineIndex, line) in section.lines.enumerated() {
                guard case let .checklist(item) = line else { continue }
                if matches(item.reference, target: target) {
                    matchedPaths.append((sectionIndex, lineIndex))
                }
            }
        }

        guard matchedPaths.count == 1, let path = matchedPaths.first else {
            if matchedPaths.isEmpty {
                throw TodoMutationError.itemResolutionFailed(target)
            }
            throw TodoMutationError.ambiguousItem(target)
        }

        guard case let .checklist(item) = document.sections[path.sectionIndex].lines[path.lineIndex] else {
            throw TodoMutationError.itemResolutionFailed(target)
        }

        let toggled = TodoChecklistItem(
            reference: TodoItemReference(
                filePath: item.reference.filePath,
                sectionName: item.reference.sectionName,
                occurrenceIndex: item.reference.occurrenceIndex,
                normalizedText: item.reference.normalizedText,
                isChecked: !item.isChecked
            ),
            text: item.text,
            isChecked: !item.isChecked,
            sourceLineIndex: item.sourceLineIndex
        )
        document.sections[path.sectionIndex].lines[path.lineIndex] = .checklist(toggled)
        return document
    }

    public func add(document: TodoDocument, request: TodoAddRequest) throws -> (document: TodoDocument, reference: TodoItemReference) {
        let normalizedText = TodoDocument.normalize(text: request.text)
        guard !normalizedText.isEmpty else {
            throw TodoMutationError.emptyText
        }

        var document = document
        let targetSectionName = try resolveTargetSection(in: document, request: request)

        if let sectionIndex = document.sections.firstIndex(where: { $0.name == targetSectionName }) {
            let occurrence = document.sections[sectionIndex].checklistItems.count
            let reference = TodoItemReference(
                filePath: document.filePath,
                sectionName: targetSectionName,
                occurrenceIndex: occurrence,
                normalizedText: normalizedText,
                isChecked: false
            )
            let item = TodoChecklistItem(reference: reference, text: request.text.trimmingCharacters(in: .whitespacesAndNewlines), isChecked: false, sourceLineIndex: -1)
            var insertionIndex = document.sections[sectionIndex].lines.count
            while insertionIndex > 0 {
                if case let .passthrough(raw) = document.sections[sectionIndex].lines[insertionIndex - 1], raw.isEmpty {
                    insertionIndex -= 1
                    continue
                }
                break
            }
            document.sections[sectionIndex].lines.insert(.checklist(item), at: insertionIndex)
            return (document, reference)
        }

        let reference = TodoItemReference(
            filePath: document.filePath,
            sectionName: targetSectionName,
            occurrenceIndex: 0,
            normalizedText: normalizedText,
            isChecked: false
        )
        let newSection = TodoSection(
            name: targetSectionName,
            headingLine: "### \(targetSectionName)",
            lines: [
                .checklist(TodoChecklistItem(reference: reference, text: request.text.trimmingCharacters(in: .whitespacesAndNewlines), isChecked: false, sourceLineIndex: -1)),
                .passthrough("")
            ],
            isManaged: true
        )
        let insertionIndex = insertionIndex(for: targetSectionName, in: document.sections, managedOrder: document.managedSectionOrder)
        document.sections.insert(newSection, at: insertionIndex)
        return (document, reference)
    }

    private func resolveTargetSection(in document: TodoDocument, request: TodoAddRequest) throws -> String {
        let candidates = [request.preferredSection, request.lastUsedSection, "OTHERS"]
        for candidate in candidates.compactMap({ $0 }) {
            if document.managedSectionOrder.contains(candidate) {
                return candidate
            }
        }
        throw TodoMutationError.sectionResolutionFailed(request.preferredSection ?? request.lastUsedSection ?? "OTHERS")
    }

    private func insertionIndex(for targetSectionName: String, in sections: [TodoSection], managedOrder: [String]) -> Int {
        let targetOrder = managedOrder.firstIndex(of: targetSectionName) ?? managedOrder.count

        for (index, section) in sections.enumerated() {
            guard let order = managedOrder.firstIndex(of: section.name), order > targetOrder else { continue }
            return index
        }

        var lastPriorManagedIndex: Int?
        for (index, section) in sections.enumerated() {
            guard let order = managedOrder.firstIndex(of: section.name), order < targetOrder else { continue }
            lastPriorManagedIndex = index
        }

        if let lastPriorManagedIndex {
            return lastPriorManagedIndex + 1
        }

        return sections.count
    }

    private func matches(_ reference: TodoItemReference, target: TodoItemReference) -> Bool {
        reference.sectionName == target.sectionName &&
        reference.occurrenceIndex == target.occurrenceIndex &&
        reference.normalizedText == target.normalizedText &&
        reference.isChecked == target.isChecked
    }
}

public struct TodoDocumentSnapshot: Equatable, Sendable {
    public let document: TodoDocument
    public let fingerprint: TodoDocumentFingerprint

    public init(document: TodoDocument, fingerprint: TodoDocumentFingerprint) {
        self.document = document
        self.fingerprint = fingerprint
    }
}

public struct TodoFileMutationService {
    private let engine: TodoMutationEngine
    private let fileManager: FileManager

    public init(engine: TodoMutationEngine = TodoMutationEngine(), fileManager: FileManager = .default) {
        self.engine = engine
        self.fileManager = fileManager
    }

    public func loadDocument(at url: URL, managedSectionOrder: [String] = TodoDocument.defaultManagedSectionOrder) throws -> TodoDocumentSnapshot {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let document = TodoDocument.parse(contents, filePath: url.path, managedSectionOrder: managedSectionOrder)
        return TodoDocumentSnapshot(document: document, fingerprint: TodoDocumentFingerprint(contents: contents))
    }

    @discardableResult
    public func toggleItem(
        at url: URL,
        target: TodoItemReference,
        expectedFingerprint: TodoDocumentFingerprint? = nil,
        managedSectionOrder: [String] = TodoDocument.defaultManagedSectionOrder
    ) throws -> TodoDocumentSnapshot {
        let loaded = try loadDocument(at: url, managedSectionOrder: managedSectionOrder)
        if let expectedFingerprint, expectedFingerprint != loaded.fingerprint {
            let reparsed = try engine.toggle(document: loaded.document, target: target)
            return try write(document: reparsed, to: url)
        }
        let updated = try engine.toggle(document: loaded.document, target: target)
        return try write(document: updated, to: url)
    }

    @discardableResult
    public func addItem(
        at url: URL,
        request: TodoAddRequest,
        expectedFingerprint: TodoDocumentFingerprint? = nil,
        managedSectionOrder: [String] = TodoDocument.defaultManagedSectionOrder
    ) throws -> (snapshot: TodoDocumentSnapshot, reference: TodoItemReference) {
        let loaded = try loadDocument(at: url, managedSectionOrder: managedSectionOrder)
        if let expectedFingerprint, expectedFingerprint != loaded.fingerprint {
            let result = try engine.add(document: loaded.document, request: request)
            return (try write(document: result.document, to: url), result.reference)
        }
        let result = try engine.add(document: loaded.document, request: request)
        return (try write(document: result.document, to: url), result.reference)
    }

    private func write(document: TodoDocument, to url: URL) throws -> TodoDocumentSnapshot {
        let rendered = document.render()
        if !fileManager.fileExists(atPath: url.deletingLastPathComponent().path) {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try rendered.data(using: .utf8)?.write(to: url, options: .atomic)
        return TodoDocumentSnapshot(document: TodoDocument.parse(rendered, filePath: url.path, managedSectionOrder: document.managedSectionOrder), fingerprint: TodoDocumentFingerprint(contents: rendered))
    }
}
