import Foundation

public struct Article: Equatable, Sendable {
    public var title: String
    public var date: String
    public var excerpt: String
    public var body: String
    public var extraFields: [String]

    public init(markdown: String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
        var values: [String: String] = [:]
        extraFields = []
        if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") {
            for line in lines[1..<end] {
                guard let colon = line.firstIndex(of: ":") else {
                    extraFields.append(line)
                    continue
                }
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if value.count >= 2, let first = value.first, let last = value.last,
                   (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                    value = String(value.dropFirst().dropLast())
                }
                if ["title", "publishedAt", "excerpt"].contains(key) { values[key] = value }
                else { extraFields.append(line) }
            }
            lines = Array(lines.dropFirst(end + 1))
            if lines.first == "" { lines.removeFirst() }
        }
        body = lines.joined(separator: "\n")
        title = values["title"] ?? lines.first(where: { $0.hasPrefix("# ") }).map { String($0.dropFirst(2)) } ?? ""
        date = values["publishedAt"] ?? Self.today
        excerpt = values["excerpt"] ?? ""
    }

    public static var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public static func slug(from title: String) -> String {
        title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func validSlug(_ slug: String) -> Bool {
        slug.count <= 120 && slug.range(of: "^[a-z0-9]+(?:[-_][a-z0-9]+)*$", options: .regularExpression) != nil
    }

    public var preparedForExport: Article {
        var prepared = self
        var lines = body.components(separatedBy: "\n")
        if lines.first == "# " + title {
            lines.removeFirst()
            if lines.first == "" { lines.removeFirst() }
            prepared.body = lines.joined(separator: "\n")
        }
        return prepared
    }

    public var wordCount: Int { body.split(whereSeparator: { $0.isWhitespace }).count }

    public func validate(slug: String) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ArticleError.invalid("Add an article title.") }
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ArticleError.invalid("Write something before preparing an article.") }
        guard Self.validSlug(slug) else { throw ArticleError.invalid("Use lowercase letters, numbers, and hyphens in the URL slug.") }
        guard ![title, excerpt].contains(where: { $0.contains("\n") || $0.contains("\r") || $0.contains("\0") }) else {
            throw ArticleError.invalid("Keep the title and excerpt on a single line.")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let parsed = formatter.date(from: date), formatter.string(from: parsed) == date else {
            throw ArticleError.invalid("Use a valid date in YYYY-MM-DD format.")
        }
        guard markdown.utf8.count < 900_000 else { throw ArticleError.invalid("This article is too large. Keep Markdown files under 900 KB.") }
    }

    public var markdown: String {
        var fields = ["title: \"\(title)\"", "publishedAt: \"\(date)\""]
        if !excerpt.isEmpty { fields.append("excerpt: \"\(excerpt)\"") }
        fields += extraFields
        return "---\n" + fields.joined(separator: "\n") + "\n---\n\n" + body
    }
}

public enum ArticleError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

public struct Publication: Equatable, Sendable {
    public let slug: String
    public let title: String
    public let markdown: String
    public init(article: Article, slug: String) throws {
        try article.validate(slug: slug)
        self.slug = slug
        title = article.title
        markdown = article.markdown
    }
    public var filename: String { "\(slug).md" }
}
