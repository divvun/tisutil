# User sessions

TIS state belongs to one user's login session. Installers run as root,
outside any user session. These rules let `tisutil` act on the right user's
state from there.

> [spec:tis:req:session.console-user]
> `tisutil` MUST find the console user with `SCDynamicStoreCopyConsoleUser`.
> When the console is at `loginwindow`, or no user is logged in, it MUST
> treat this as "no user session".

> [spec:tis:req:session.reexec]
> When `tisutil` runs as root and a command reads or changes per-user TIS
> state, it MUST run itself again as the target user inside that user's
> bootstrap context (`launchctl asuser <uid>`). The default target is the
> console user; `--user <name>` picks another logged-in user. The parent
> MUST forward the arguments, stdout and stderr, and MUST exit with the
> child's exit status.

> [spec:tis:req:session.prefs-fallback+2]
> When `tisutil` runs as root and the user named with `--user` has no GUI
> session, `enable` and `disable` MUST fall back to changing that user's
> enabled-source preferences. Sources that come with macOS MUST use
> `AppleEnabledInputSources` in `com.apple.HIToolbox`; third-party sources
> MUST use `AppleEnabledThirdPartyInputSources` in `com.apple.inputsources`.
> The change MUST go through `cfprefsd` (CFPreferences), not by editing the
> plist file directly, so that the preferences cache does not overwrite it.
> Existing unrelated entries MUST be preserved, and enabling an existing
> entry MUST NOT add a duplicate. The command MUST report that the change
> applies at the user's next login.
>
> Enabling a third-party source MUST require `--force` when the user has no
> GUI session. With `--force`, the command MUST record the enablement without
> requiring user approval. Without it, the command MUST exit with code `77`
> without changing preferences, explaining that `--force` records enablement
> for the next login or the user can enable it after logging in. Disabling a
> third-party source MUST NOT require `--force` or user approval.

> [spec:tis:req:session.privilege]
> A command that targets a user other than the one running `tisutil` MUST
> exit with code `77` unless `tisutil` runs as root.
