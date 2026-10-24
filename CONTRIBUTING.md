# Contributing to Zen Writer

Zen Writer is a small native macOS app for focused writing. Fork it to suit your own workflow, or contribute improvements back through a pull request.

## Set up

Use macOS 14 or newer and a Swift 6.0+ toolchain (Xcode or working Swift command-line tools).

```sh
git clone https://github.com/nimblegeek/zen-writer.git
cd zen-writer
./scripts/test.sh
./scripts/build-app.sh
open 'build/Zen Writer.app'
```

You can also open `Package.swift` in Xcode. There are no external package dependencies or required accounts. The build script selects the installed Xcode toolchain when available and bundles the fonts and app icon.

## Make a change

1. Fork the repository and create a branch in your fork.
2. Keep changes focused and preserve the simple writing experience and local Markdown file format.
3. Run `./scripts/test.sh` and `./scripts/build-app.sh`. For archive or export changes, add a regression test when behavior changes. For interface changes, check the themes, keyboard shortcuts, preview, and saving.
4. Open a pull request explaining the problem, the change, and how you checked it. Include a screenshot for visible interface changes.

Use sample writing and temporary folders when testing storage or export behavior. Keep personal documents, account credentials, signing certificates, `.build/`, and `build/` out of commits.

## Report a bug

Open a GitHub issue with your macOS version, app version, steps to reproduce, and expected behavior. Use a small sample document if the issue depends on Markdown content.

## License

Contributions to Zen Writer's original code are made under the repository's MIT License. Preserve the separate license notices for bundled fonts and any other third-party material.
