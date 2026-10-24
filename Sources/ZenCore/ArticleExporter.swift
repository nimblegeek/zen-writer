import Foundation

public struct PreparedExport: Sendable {
    public let publication: Publication
    public let destination: URL
    public let previousData: Data?
    public var isUpdate: Bool { previousData != nil }
    public var isUnchanged: Bool { previousData == Data(publication.markdown.utf8) }
    public var previousMarkdown: String? { previousData.flatMap { String(data: $0, encoding: .utf8) } }
}

public enum ArticleExporter {
    public static func prepare(_ publication: Publication, directory: URL) throws -> PreparedExport {
        let folder = directory.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArticleError.invalid("Choose an existing folder for your exported articles.")
        }
        let destination = folder.appendingPathComponent(publication.filename)
        let previous = try existingData(at: destination)
        return PreparedExport(publication: publication, destination: destination, previousData: previous)
    }

    @discardableResult public static func save(_ prepared: PreparedExport) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var outcome: Result<URL, Error> = .failure(ArticleError.invalid("Could not coordinate the article save."))
        coordinator.coordinate(writingItemAt: prepared.destination, options: .forReplacing, error: &coordinationError) { destination in
            do {
                let current = try existingData(at: destination)
                guard current == prepared.previousData else {
                    throw ArticleError.invalid("This article changed since you reviewed it. Check the current version before saving again.")
                }
                if !prepared.isUnchanged {
                    let data = Data(prepared.publication.markdown.utf8)
                    if current == nil { try data.write(to: destination, options: .withoutOverwriting) }
                    else { try data.write(to: destination, options: .atomic) }
                }
                outcome = .success(destination)
            } catch { outcome = .failure(error) }
        }
        if let coordinationError { throw coordinationError }
        return try outcome.get()
    }

    private static func existingData(at url: URL) throws -> Data? {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ArticleError.invalid("The destination must be a regular Markdown file, not a folder or symbolic link.")
        }
        let data = try Data(contentsOf: url)
        guard String(data: data, encoding: .utf8) != nil else { throw ArticleError.invalid("The existing file is not UTF-8 Markdown.") }
        return data
    }
}
