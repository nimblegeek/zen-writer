import XCTest
@testable import ZenCore

final class ArticleTests: XCTestCase {
    func testPlainMarkdownRoundTripsWithoutDroppingText() {
        let source = "# A thought\n\nHello **world**. Åäö 🎻\n"
        let article = Article(markdown: source)
        XCTAssertEqual(article.title, "A thought")
        XCTAssertEqual(article.body, source)
        XCTAssertEqual(Article(markdown: article.markdown).body, source)
    }
    func testExistingWebsiteMetadataAndUnknownFieldsSurvive() {
        let source = "---\ntitle: \"Time: to build\"\nexcerpt: \"Let's make things.\"\npublishedAt: \"2026-10-24\"\ntags: [writing, learning]\n---\n\nA paragraph.\n"
        let article = Article(markdown: source)
        XCTAssertEqual(article.title, "Time: to build")
        XCTAssertEqual(article.date, "2026-10-24")
        XCTAssertEqual(article.excerpt, "Let's make things.")
        XCTAssertTrue(article.markdown.contains("tags: [writing, learning]"))
        XCTAssertEqual(Article(markdown: article.markdown), article)
    }
    func testWindowsNewlinesAreAccepted() {
        let article = Article(markdown: "---\r\ntitle: Test\r\npublishedAt: 2026-10-24\r\n---\r\n\r\nHello\r\n")
        XCTAssertEqual(article.title, "Test")
        XCTAssertEqual(article.body, "Hello\n")
    }
    func testMalformedFrontmatterDoesNotDiscardContent() {
        let source = "---\ntitle: unfinished\n\nKeep this text."
        XCTAssertEqual(Article(markdown: source).body, source)
    }
    func testSlugNormalizesSwedishAndRejectsTraversal() {
        XCTAssertEqual(Article.slug(from: "Förändring, ÅÄÖ & a Builder!"), "forandring-aao-a-builder")
        for invalid in ["../test", "a/b", "", "-test", "test--one", "article?ref=main", "Uppercase", String(repeating: "a", count: 121)] {
            XCTAssertFalse(Article.validSlug(invalid), invalid)
        }
        XCTAssertTrue(Article.validSlug("day_one"))
    }
    func testValidationRejectsEmptyBodyInvalidDateAndMultilineMetadata() throws {
        var article = Article(markdown: "Hello")
        article.title = "Test"
        article.date = "2026-02-30"
        XCTAssertThrowsError(try article.validate(slug: "test"))
        article.date = "2026-10-24"
        XCTAssertNoThrow(try article.validate(slug: "test"))
        article.title = "Title\npublishedAt: 2000-01-01"
        XCTAssertThrowsError(try article.validate(slug: "test"))
        article.title = "Test"
        article.body = " \n\t"
        XCTAssertThrowsError(try article.validate(slug: "test"))
    }
    func testExportFilenameIsSafe() throws {
        var article = Article(markdown: "Body")
        article.title = "A thought"
        let publication = try Publication(article: article, slug: "a-thought")
        XCTAssertEqual(publication.filename, "a-thought.md")
        XCTAssertThrowsError(try Publication(article: article, slug: "../../index"))
    }
    func testExportMovesMatchingHeadingIntoMetadata() {
        let source = "# A thought\n\nKeep **all** of this. Åäö 🎻\n"
        let article = Article(markdown: source).preparedForExport
        XCTAssertEqual(article.title, "A thought")
        XCTAssertEqual(article.body, "Keep **all** of this. Åäö 🎻\n")
        XCTAssertEqual(Article(markdown: article.markdown).title, "A thought")
        var distinct = Article(markdown: source)
        distinct.title = "Another title"
        XCTAssertEqual(distinct.preparedForExport.body, source)
    }
    func testWordCountExcludesFrontmatter() {
        XCTAssertEqual(Article(markdown: "---\ntitle: Not counted here\n---\n\nJust three words.").wordCount, 3)
    }
}

final class ExporterTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func publication(_ body: String = "A draft.") throws -> Publication {
        var article = Article(markdown: body); article.title = "Test article"
        return try Publication(article: article, slug: "test-article")
    }
    func testNewArticleIsSavedInAnyChosenFolder() throws {
        let publication = try publication()
        let prepared = try ArticleExporter.prepare(publication, directory: root)
        XCTAssertFalse(prepared.isUpdate)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.destination.path))
        let url = try ArticleExporter.save(prepared)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), publication.markdown)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["test-article.md"])
    }
    func testExistingArticleIsDetectedAndUpdated() throws {
        let first = try ArticleExporter.prepare(publication(), directory: root)
        try ArticleExporter.save(first)
        let updated = try ArticleExporter.prepare(publication("Updated body."), directory: root)
        XCTAssertTrue(updated.isUpdate)
        XCTAssertEqual(updated.previousMarkdown, first.publication.markdown)
        try ArticleExporter.save(updated)
        XCTAssertEqual(try String(contentsOf: updated.destination, encoding: .utf8), updated.publication.markdown)
    }
    func testConcurrentEditIsPreserved() throws {
        let first = try ArticleExporter.prepare(publication(), directory: root)
        try ArticleExporter.save(first)
        let reviewed = try ArticleExporter.prepare(publication("My update."), directory: root)
        try "Someone else's edit".write(to: reviewed.destination, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ArticleExporter.save(reviewed))
        XCTAssertEqual(try String(contentsOf: reviewed.destination, encoding: .utf8), "Someone else's edit")
    }
    func testNewFileAppearingAfterReviewIsNotOverwritten() throws {
        let reviewed = try ArticleExporter.prepare(publication(), directory: root)
        try "New file".write(to: reviewed.destination, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ArticleExporter.save(reviewed))
        XCTAssertEqual(try String(contentsOf: reviewed.destination, encoding: .utf8), "New file")
    }
    func testIdenticalExportIsDetected() throws {
        let first = try ArticleExporter.prepare(publication(), directory: root)
        try ArticleExporter.save(first)
        XCTAssertTrue(try ArticleExporter.prepare(publication(), directory: root).isUnchanged)
    }
    func testMissingFolderAndSymbolicLinkAreRejected() throws {
        XCTAssertThrowsError(try ArticleExporter.prepare(publication(), directory: root.appendingPathComponent("wrong")))
        let outside = root.appendingPathComponent("keep.md")
        try "Keep me".write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("test-article.md"), withDestinationURL: outside)
        XCTAssertThrowsError(try ArticleExporter.prepare(publication(), directory: root))
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "Keep me")
    }
}
