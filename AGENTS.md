# Working on tisutil

Guidance for coding agents and new contributors.

## Layout

| Path | What it is |
|------|------------|
| `Sources/TISKit` | Library. Every call to TIS lives here. |
| `Sources/TISUtilCommands` | The command-line interface on swift-argument-parser. Holds no TIS logic. |
| `Sources/tisutil` | Executable entry point; calls `TISUtil.main()`. |
| `Tests/TISKitTestSupport` | `FixedInputSources`, an in-memory `InputSourceProvider` for tests. |
| `Tests/TISKitTests`, `Tests/TISUtilCommandsTests` | Swift Testing suites. |
| `docs/spec/*.md` | The specification: rules addressed as `[spec:tis:<verb>:<id>]`. |
| `plan/main.styx` | The nplan work breakdown. |

## Commands

```sh
swift build
swift test
swift format --in-place --recursive Package.swift Sources Tests
nplan check        # runs the format and test checks and records their results
```

Formatting uses `.swift-format`: 4-space indentation, 100-column lines.

## Planning and commits

The project is planned with nplan.

- Find the next piece of work with `nplan next` (MCP: `nplan_next`); don't
  pick work by hand.
- New work starts as a plan node, and its behaviour as a spec rule under
  `docs/spec/`, before any code is written.
- Annotate the code that implements a rule with `// [spec:tis:req:<id>]` on
  the line above it. Annotate the tests that verify it with
  `// [spec:tis:req:<id>/test]`.
- When a rule's text changes, bump its version (`+1`, `+2`, …) in the spec,
  and update every annotation to the same version.
- Commit through `nplan commit` (MCP: `nplan_commit`). A pre-commit hook
  refuses a bare `git commit`.
- Run `nplan check` before committing, so the commit can reuse the recorded
  check results.

## Rules the code depends on

- **Main thread.** TIS aborts the process when it is called off the main
  thread. `InputSourceProvider` is `@MainActor`, and commands enter the main
  actor with `MainActor.assumeIsolated`. Keep new TIS calls behind that
  isolation.
- **Snapshots.** `InputSource` is a value snapshot. Don't keep a
  `TISInputSource` past the call that needs it.
- **Absent properties.** A property that TIS reports as absent is `nil`. It is
  never an empty string, an empty array or `false`.
- **Two IDs per layout.** A bundled keyboard layout has two IDs (see
  `LayoutIDAliases`), and TIS switches between them. Look sources up with
  `source(id:)`, never by comparing IDs directly. Don't filter
  `TISCreateInputSourceList` by ID.
- **Check every change.** TIS can return `noErr` without making a change, and
  third-party sources wait for the user to allow them. Every change goes
  through `apply(_:to:enablingFirst:timeout:)`, which polls until the change
  takes effect.
- **Stable exit codes.** Exit codes are part of the interface (see
  `ExitStatus`). Errors reach the user through `DiagnosedError`.

## Testing

- **Fakes first.** Unit tests use `FixedInputSources`. It can delay changes
  (`pausesBeforeApplying`), ignore them (`appliesChanges = false`), and rename
  sources after a change (`idsAfterChange`).
- **Live tests read only.** Tests may read the live TIS state, but must never
  enable, disable, select, register or install anything. They also must not
  assume a particular machine's input sources.
- **Manual checks.** Run these against a real machine through
  `.build/debug/tisutil`, and restore anything you change.

## Debugging on macOS

- **System log.** In zsh, `log` is a shell builtin. Use `/usr/bin/log stream`
  or `/usr/bin/log show`.
- **Where state lives.** Apple input sources are recorded as enabled in
  `com.apple.HIToolbox` → `AppleEnabledInputSources`. Third-party ones are
  recorded in `com.apple.inputsources` → `AppleEnabledThirdPartyInputSources`.
- **Stderr noise.** TIS prints warnings about broken or duplicate `.keylayout`
  files to stderr ("Keyboard Layouts: duplicate keyboard layout identifier…").
  They come from the installed layouts, not from tisutil.
