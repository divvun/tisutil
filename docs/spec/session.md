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

> [spec:tis:req:session.prefs-fallback+1]
> When `tisutil` runs as root and the user named with `--user` has no GUI
> session, `enable` and `disable` of an input source that comes with macOS
> MUST fall back to changing `AppleEnabledInputSources` in that user's
> `com.apple.HIToolbox` preferences. The change MUST go through `cfprefsd`
> (CFPreferences), not by editing the plist file directly, so that the
> preferences cache does not overwrite it. The command MUST report that the
> change applies at the user's next login.
>
> A third-party input source needs the user's own approval. For one of
> those, with or without `--force`, `tisutil` MUST NOT change any
> preference, and MUST exit with code `77`, saying that the user has to
> enable it after logging in.

> [spec:tis:req:session.privilege]
> A command that targets a user other than the one running `tisutil` MUST
> exit with code `77` unless `tisutil` runs as root.
