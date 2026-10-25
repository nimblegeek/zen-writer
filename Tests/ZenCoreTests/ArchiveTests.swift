import Foundation
import XCTest
@testable import ZenCore

final class ArchiveTests: XCTestCase {
    private var temporary: URL!
    private var store: ArchiveStore!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
        store = try ArchiveStore(root: temporary.appendingPathComponent("Archive", isDirectory: true))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }

    func testNestedArchiveListsFoldersFirstAndPreservesUnicode() throws {
        let folder = try store.create(name: "Utkast", parent: store.root, isFolder: true)
        let nested = try store.create(name: "Idéer", parent: folder, isFolder: true)
        let file = try store.create(name: "En tanke", parent: nested, isFolder: false, text: "# För framtiden\n\nÅäö ✨\n")
        _ = try store.create(name: "A text.markdown", parent: store.root, isFolder: false)
        let items = try store.contents()
        XCTAssertEqual(items.map(\.name), ["Utkast", "A text"])
        XCTAssertEqual(items[0].children?[0].children?[0].url, file)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "# För framtiden\n\nÅäö ✨\n")
    }
    func testScanIgnoresOtherFilesHiddenFilesAndSymlinks() throws {
        let outside = temporary.appendingPathComponent("outside.md")
        try Data("private".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: store.root.appendingPathComponent("linked.md"), withDestinationURL: outside)
        try Data().write(to: store.root.appendingPathComponent("photo.png"))
        try Data().write(to: store.root.appendingPathComponent(".hidden.md"))
        XCTAssertTrue(try store.contents().isEmpty)
    }
    func testNamesAndDestinationsCannotEscapeArchive() throws {
        for name in ["", "..", "../outside", "a/b", "a:b", ".hidden", "a\nb"] {
            XCTAssertThrowsError(try store.create(name: name, parent: store.root, isFolder: false), name)
        }
        XCTAssertThrowsError(try store.create(name: "outside", parent: temporary, isFolder: false))
        let link = store.root.appendingPathComponent("escape", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: temporary)
        XCTAssertThrowsError(try store.create(name: "outside", parent: link, isFolder: false))
    }
    func testDuplicateCreationAndMoveNeverOverwriteExistingWriting() throws {
        let first = try store.create(name: "First", parent: store.root, isFolder: false, text: "original")
        let second = try store.create(name: "Second", parent: store.root, isFolder: false, text: "second")
        XCTAssertThrowsError(try store.create(name: "First", parent: store.root, isFolder: false, text: "replacement"))
        XCTAssertThrowsError(try store.move(from: second, to: first))
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "original")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "second")
    }
    func testRenameAndMoveKeepTextAndNestedFolders() throws {
        let folder = try store.create(name: "Drafts", parent: store.root, isFolder: true)
        let file = try store.create(name: "First", parent: store.root, isFolder: false, text: "unsurprising words")
        let destination = try store.destination(name: "Second", parent: folder, isFolder: false)
        try store.move(from: file, to: destination)
        let renamedFolder = try store.destination(name: "Ideas", parent: store.root, isFolder: true)
        try store.move(from: folder, to: renamedFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try String(contentsOf: renamedFolder.appendingPathComponent("Second.md"), encoding: .utf8), "unsurprising words")
    }
    func testFolderCannotMoveIntoItselfOrMoveArchiveRoot() throws {
        let folder = try store.create(name: "Drafts", parent: store.root, isFolder: true)
        let child = try store.create(name: "Ideas", parent: folder, isFolder: true)
        XCTAssertThrowsError(try store.move(from: folder, to: child.appendingPathComponent("Drafts")))
        XCTAssertThrowsError(try store.move(from: store.root, to: child.appendingPathComponent("Archive")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
    }
    func testImportCopiesMarkdownAndPreservesOriginal() throws {
        let source = temporary.appendingPathComponent("Original.md")
        try Data("# A thought\n\nContent\n".utf8).write(to: source)
        let imported = try store.importMarkdown(from: source, parent: store.root)
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: imported))
        XCTAssertThrowsError(try store.importMarkdown(from: source, parent: store.root))
        XCTAssertThrowsError(try store.importMarkdown(from: temporary.appendingPathComponent("image.png"), parent: store.root))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testTrashMovesFileWithoutChangingContentsOrOtherTexts() throws {
        let file = try store.create(name: "Draft", parent: store.root, isFolder: false, text: "Åäö — keep my words")
        let other = try store.create(name: "Keep", parent: store.root, isFolder: false, text: "untouched")
        let trashed = temporary.appendingPathComponent("trashed.md")
        try store.trash(file) { try FileManager.default.moveItem(at: $0, to: trashed) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try String(contentsOf: trashed, encoding: .utf8), "Åäö — keep my words")
        XCTAssertEqual(try String(contentsOf: other, encoding: .utf8), "untouched")
        XCTAssertEqual(try store.contents().map(\.url), [other])
    }
    func testTrashMovesWholeFolderIncludingHiddenAndNonMarkdownFiles() throws {
        let folder = try store.create(name: "Drafts", parent: store.root, isFolder: true)
        let nested = try store.create(name: "Ideas", parent: folder, isFolder: true)
        _ = try store.create(name: "Thought", parent: nested, isFolder: false, text: "recoverable")
        try Data([1, 2, 3]).write(to: folder.appendingPathComponent("image.png"))
        try Data("metadata".utf8).write(to: folder.appendingPathComponent(".hidden"))
        let trashed = temporary.appendingPathComponent("Trashed folder")
        try store.trash(folder) { try FileManager.default.moveItem(at: $0, to: trashed) }
        XCTAssertTrue(try store.contents().isEmpty)
        XCTAssertEqual(try String(contentsOf: trashed.appendingPathComponent("Ideas/Thought.md"), encoding: .utf8), "recoverable")
        XCTAssertEqual(try Data(contentsOf: trashed.appendingPathComponent("image.png")), Data([1, 2, 3]))
        XCTAssertEqual(try String(contentsOf: trashed.appendingPathComponent(".hidden"), encoding: .utf8), "metadata")
    }
    func testTrashRejectsRootOutsideFilesSymlinksAndMissingItemsBeforeMutation() throws {
        let outside = temporary.appendingPathComponent("outside.md")
        try Data("outside".utf8).write(to: outside)
        let link = store.root.appendingPathComponent("linked.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let directoryLink = store.root.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: directoryLink, withDestinationURL: temporary)
        let nonMarkdown = store.root.appendingPathComponent("image.png")
        try Data([4]).write(to: nonMarkdown)
        for source in [store.root, outside, link, directoryLink.appendingPathComponent("outside.md"), nonMarkdown, store.root.appendingPathComponent("missing.md")] {
            var invoked = false
            XCTAssertThrowsError(try store.trash(source) { _ in invoked = true })
            XCTAssertFalse(invoked, source.path)
        }
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "outside")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.root.path))
    }
    func testTrashFailureKeepsOriginalWriting() throws {
        let file = try store.create(name: "Keep", parent: store.root, isFolder: false, text: "still here")
        XCTAssertThrowsError(try store.trash(file) { _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "still here")
        XCTAssertEqual(try store.contents().map(\.url), [file])
    }
}
