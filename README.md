# tisutil

`tisutil` is a command-line tool for macOS Text Input Sources (TIS): keyboard
layouts, input methods and input modes. It lists and inspects them, enables,
disables and selects them, and installs and registers new ones. It works both
interactively and from installers that run as root.

It is built on `TISKit`, a Swift library in this package that wraps the Carbon
Text Input Sources API in value types and typed errors.

## Requirements

- macOS 13 or later.
- A Swift 6 toolchain (Xcode 16 or later) to build.

## Building

```sh
swift build -c release
cp .build/release/tisutil /usr/local/bin/
```

During development, `swift run tisutil <command>` builds and runs in one step.

## Usage

```sh
tisutil list                                  # enabled input sources
tisutil list --all --type keyboard-layout     # every installed keyboard layout
tisutil list --language se                    # sources for Northern Sámi (se, se-NO, …)
tisutil current                               # the current keyboard input source
tisutil current --layout                      # the current keyboard layout
tisutil show com.apple.keylayout.ABC          # every property of one source

tisutil enable com.apple.keylayout.Irish
tisutil enable --force eu.avette.inputmethod.Avette # skip the macOS approval sheet
tisutil select --enable no.uit.giella.keyboards.sme.keyboardlayout.sme.seNO
tisutil disable com.apple.keylayout.Irish

tisutil register "/Library/Keyboard Layouts/Example.bundle"
tisutil install --enable --select Example.bundle      # into ~/Library
sudo tisutil install --system --enable Example.bundle # into /Library
```

Every command takes `--json` and then prints exactly one JSON document.
Every input source is printed with the same fields, and absent properties are
`null`. Run `tisutil help <command>` for all options.

### Exit status

| Code | Meaning |
|-----:|---------|
| 0 | Success |
| 1 | A TIS call or file-system operation failed, or a change did not take effect |
| 2 | No input source matches the requested ID or filter |
| 64 | Usage error |
| 77 | The operation needs a privilege or user session that tisutil does not have |

These values do not change between releases.

### Running as root

TIS state belongs to a user's login session. When `tisutil` runs as root, as
it does in a package `postinstall` script, it runs itself again as the console
user through `launchctl asuser` and `sudo -u`, so that it acts in that user's
session. `--user <name>` targets another logged-in user. `install --system`
copies the item as root, then registers it in the user's session.

If nobody is logged in, `install --system` still copies the item. It becomes
available at the next login, and the command exits 0 unless `--enable` or
`--select` was given.

`sudo tisutil enable --user <name> <id>` (and `disable`) for a user who is not
logged in records the change in that user's preferences, to take effect at
their next login. To enable a third-party source this way, add `--force`:

```sh
sudo tisutil enable --force --user <name> <id>
```

Without `--force`, offline third-party enablement exits 77. Disabling a source
for the next login works for both Apple and third-party sources.

### Third-party input source approval

On current macOS, enabling a third-party keyboard layout or input method asks
the user to allow it. The source is enabled only once they do. `tisutil`
waits for the change to take effect, for up to 60 seconds by default
(`--timeout <seconds>`). It exits 1 if the user denies the request or does not
answer. Apple's own input sources are enabled immediately.

`--force` skips the macOS approval sheet. Use it with `enable`, `select --enable`,
`register --enable` or `--select`, and `install --enable` or `--select`.
The command still checks that the source became enabled.

### Dictation

```sh
tisutil dictation status        # on/off, language, input source, auto-enable
tisutil dictation languages     # locales and whether their on-device models are installed
tisutil dictation auto-enable on
```

`tisutil` can report whether dictation is on, but cannot turn it on or off:
macOS accepts that change only from its own entitled processes, such as
System Settings.

### Input source IDs

A keyboard layout in a bundle has two IDs: the one its `Info.plist` declares
under `KLInfo_<name>` → `TISInputSourceID`, and one TIS generates,
`<bundle ID>.keylayout.<name>`. TIS reports either of them, and can switch
between them from one call to the next. `tisutil` accepts both forms wherever
it takes an ID.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option.
