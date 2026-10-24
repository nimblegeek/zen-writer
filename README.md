# Zen Writer

An open-source native macOS Markdown writing app, built as a personal space for clear thinking. SwiftUI for the window and document lifecycle, AppKit for the text editor. Plain UTF-8 Markdown files; no database and no runtime web view.

## Run

The app requires macOS 14 or newer. It runs by itself: no website, local web server, browser, account, or internet connection is needed.

To build from source, use Xcode or working Swift command-line tools with Swift 6.0 or newer. Clone the repository over HTTPS; no GitHub account is required to clone a public repository.

```sh
git clone https://github.com/nimblegeek/zen-writer.git
cd zen-writer
./scripts/build-app.sh
open 'build/Zen Writer.app'
```

Open `Package.swift` in Xcode to work on the source. `./scripts/test.sh` runs the core tests with the same toolchain. The build script prefers the installed Xcode toolchain when available, without changing the machine's global developer directory.

Copy `build/Zen Writer.app` into `~/Applications` or `/Applications` to install it. The app bundle contains everything it needs; the source project is only needed for development.

The generated app is ad-hoc signed for local use and is not notarized by Apple. The GitHub releases are preview builds for Apple Silicon Macs running macOS 14 or newer; downloaded copies may be blocked by Gatekeeper. Building from source is available with the commands above.

## Releases

[GitHub releases](https://github.com/nimblegeek/zen-writer/releases) contain the app ZIP and a SHA-256 checksum. Extract the ZIP and copy `Zen Writer.app` into `~/Applications`. Your writing archive is stored separately from the app bundle and is preserved when the app is replaced. There is no automatic updater.

To test, build, verify the local signature, and package a release for your Mac’s architecture:

```sh
./scripts/package-release.sh
```

Artifacts are written to `build/releases/`, which is excluded from Git. The package contains the app, not your archive or document preferences.

## Writing

- **⌘N / ⌘O / ⌘S**: new, open, and save a normal `.md` file. macOS handles document autosave and multiple windows.
- **⌘F**: find in the native editor. Standard undo, spelling, and text editing shortcuts work.
- **⇧⌘P**: switch between Markdown and a native reading preview.
- **⇧⌘F**: focus mode; repeat to leave.
- **Aa** opens the font and appearance panel: **Work Sans** for writing, **JetBrains Mono** for technical documents, and **Circular style**. JetBrains Mono and Work Sans are bundled with their SIL OFL licenses. Circular uses an installed Circular font when available, otherwise macOS’s Avenir Next; the interface names the actual font. Font family, text size, and the **Gruvbox Light**, **Gruvbox Dark**, or **Tokyo Night** theme persist across launches. The editor and reading preview use the selected font; code blocks in the preview use JetBrains Mono.
- The preview handles headings, paragraphs, links, emphasis, basic lists, quotes, and fenced code. It is a reading preview, not an exact renderer of the website. Embedded media, tables, and nested lists remain in the Markdown but are not fully rendered in this first version.

## Window and menus

The app has its own themed title bar, window buttons, document strip, archive selection, and font/document menus. Drag an empty part of the top bar to move the window; double-click it to zoom. The top-left controls close, minimize, and maximize or restore the window. Closing still uses macOS document handling to protect unsaved writing.

The **…** menu contains New, Open, Save, and Export. The macOS global menu bar, keyboard shortcuts, and standard file dialogs remain available. Appearance changes only affect how Markdown is displayed, never the file’s contents.

## Local writing archive

**⌘B** shows or hides the sidebar, also available through the toolbar or **Archive** menu. Use the folder and pencil buttons to create folders and Markdown texts inside the selected folder. Subfolders are supported. Right-click an item to rename it, move it to another folder, or reveal it in Finder.

The archive starts in `~/Library/Application Support/Zen Writer/Archive`. It contains ordinary `.md` files and folders, with no account or database. The sidebar’s options menu can import Markdown files (copies; originals stay in place), reveal the archive in Finder, select another archive folder, or refresh the list. Choosing a different folder does not move your existing files. The selected archive and sidebar visibility persist across launches.

Selecting a text opens it in the app’s themed document strip, backed by native macOS documents. Existing documents stay open, preserving edits and undo history; use **⌘S** to save immediately. Renaming or moving an open text uses macOS document handling. Close texts inside a folder before moving or renaming that folder. Existing files are never silently replaced. Files created elsewhere appear after returning to the app or choosing **Refresh archive**. Use Finder to delete or reorganize closed files.

## Optional article export

**Export** opens a sheet for title, filename, publication date, excerpt, and a preview. **Apply metadata** adds frontmatter to the document. **Export Markdown…** saves the article anywhere using the standard Save dialog.

You can optionally choose a **Quick export folder**. **Save to folder** then writes `<filename>.md` there, with confirmation before replacing an existing file. Concurrent changes are detected before replacement. No website folder is selected by default. **Clear** disconnects the shortcut.

For Jonas’s blog, you can explicitly select its `src/thoughts` directory as the quick export folder. That is only a convenient local destination: the app has no dependency on the website project and never commits, pushes, or deploys anything.

A matching first Markdown heading becomes the article title, avoiding a duplicate heading in the body. Existing frontmatter fields are preserved. The first version exports text; media attachments remain separate files.

Automated tests cover archive folders, renaming and moves, imports, duplicate protection, article parsing, Unicode, path validation, local export, replacement, concurrent changes, and symbolic links. Test exports use temporary folders with no website structure.

## Build on it

Fork it, make it your own, or send a pull request. Bug reports and focused improvements are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

[Watch the 19-second demo](https://www.jonasasihlen.com/demos/zen-writer-19s.mp4) or [download a release](https://github.com/nimblegeek/zen-writer/releases).

## License

Zen Writer's original source code is available under the [MIT License](LICENSE). You can use, modify, and redistribute it, including commercially, while keeping the copyright and license notice.

Bundled JetBrains Mono and Work Sans fonts remain under their own SIL Open Font License 1.1; the license files and upstream revisions are in [Resources/Fonts](Resources/Fonts). Circular is not bundled.

## Design references

- Native document lifecycle: [Apple DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)
- Bundled fonts: [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), [Work Sans](https://github.com/weiweihuanghuang/Work-Sans). Exact upstream revisions and licenses are in `Resources/Fonts`.
- Palette values: [Gruvbox](https://github.com/morhetz/gruvbox/blob/master/colors/gruvbox.vim), [Tokyo Night](https://github.com/folke/tokyonight.nvim/tree/main/lua/tokyonight/colors)
