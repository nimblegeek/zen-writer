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
}
