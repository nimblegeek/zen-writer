import Foundation

public struct ArchiveItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let children: [ArchiveItem]?
    public var id: URL { url }
    public var isFolder: Bool { children != nil }
    public var name: String { isFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent }
}

public struct ArchiveStore: Sendable {
    public let root: URL
    public init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    }
    public func contents() throws -> [ArchiveItem] {
        var count = 0
        func scan(_ directory: URL, depth: Int) throws -> [ArchiveItem] {
            guard depth < 32 else { throw ArticleError.invalid("This archive has too many nested folders.") }
            let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey], options: [.skipsHiddenFiles])
            var items: [ArchiveItem] = []
            for entry in entries {
                let url = entry.standardizedFileURL
                count += 1
                guard count <= 10_000 else { throw ArticleError.invalid("This folder is too large for the archive. Choose a smaller writing folder.") }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    items.append(ArchiveItem(url: url, children: try scan(url, depth: depth + 1)))
                } else if values.isRegularFile == true, ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                    items.append(ArchiveItem(url: url, children: nil))
                }
            }
            return items.sorted {
                if $0.isFolder != $1.isFolder { return $0.isFolder }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return try scan(root, depth: 0)
    }
    public func validate(_ url: URL, allowRoot: Bool = true) throws {
        let path = url.standardizedFileURL
        let resolved = path.resolvingSymlinksInPath()
        guard path.path == resolved.path,
              resolved.path.hasPrefix(root.path + "/") || (allowRoot && resolved.path == root.path) else {
            throw ArticleError.invalid("Choose a file or folder inside this archive.")
        }
    }
    public func destination(name: String, parent: URL, isFolder: Bool) throws -> URL {
        try validate(parent)
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &directory), directory.boolValue else { throw ArticleError.invalid("The destination folder no longer exists.") }
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.hasPrefix("."), clean.count <= 120,
              clean.rangeOfCharacter(from: CharacterSet(charactersIn: "/:\0\n\r")) == nil else {
            throw ArticleError.invalid("Choose a name without slashes, colons, or line breaks.")
        }
        if !isFolder, !["md", "markdown"].contains((clean as NSString).pathExtension.lowercased()) { clean += ".md" }
        let destination = parent.appendingPathComponent(clean, isDirectory: isFolder)
        try validate(destination, allowRoot: false)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ArticleError.invalid("That name already exists. Choose another name.") }
        return destination
    }
    @discardableResult public func create(name: String, parent: URL, isFolder: Bool, text: String = "") throws -> URL {
        let target = try destination(name: name, parent: parent, isFolder: isFolder)
        if isFolder { try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false) }
        else { try Data(text.utf8).write(to: target, options: .withoutOverwriting) }
        return target.standardizedFileURL
    }
    public func validateMove(from source: URL, to destination: URL) throws {
        try validate(source, allowRoot: false)
        try validate(destination, allowRoot: false)
        guard FileManager.default.fileExists(atPath: source.path),
              !FileManager.default.fileExists(atPath: destination.path) else { throw ArticleError.invalid("The original file is missing, or that name already exists.") }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory)
        if isDirectory.boolValue && destination.path.hasPrefix(source.path + "/") { throw ArticleError.invalid("A folder cannot be moved into itself.") }
    }
    public func move(from source: URL, to destination: URL) throws {
        try validateMove(from: source, to: destination)
        try FileManager.default.moveItem(at: source, to: destination)
    }
    @discardableResult public func importMarkdown(from source: URL, parent: URL) throws -> URL {
        guard ["md", "markdown"].contains(source.pathExtension.lowercased()) else { throw ArticleError.invalid("Choose a Markdown file (.md or .markdown).") }
        let text = try String(contentsOf: source, encoding: .utf8)
        return try create(name: source.lastPathComponent, parent: parent, isFolder: false, text: text)
    }
}
