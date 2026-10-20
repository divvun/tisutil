# State commands

Commands that change which input sources are enabled or selected.

> [spec:tis:req:mutate.enable-disable+1]
> Without `--force`, `tisutil enable <id>` MUST call `TISEnableInputSource`, and
> `tisutil disable <id>` MUST call `TISDisableInputSource`. Enabling a source
> that is already enabled MUST succeed and change nothing. The same holds
> for disabling a source that is already disabled.

> [spec:tis:req:mutate.select]
> `tisutil select <id>` MUST call `TISSelectInputSource`, and
> `tisutil deselect <id>` MUST call `TISDeselectInputSource`. If the source is
> not select-capable, the command MUST fail without calling TIS. If the
> source is not enabled, `select` MUST fail unless `--enable` is given, in
> which case it MUST enable the source first.

> [spec:tis:req:mutate.verify+2]
> TIS can return `noErr` before a change takes effect, or without making it
> at all. For a third-party input source, macOS asks the user to allow an
> enable and applies it only once they do. After every enable, disable,
> select or deselect, `tisutil` MUST read the source again until its state
> matches the request, for up to 60 seconds or the number of seconds given
> with `--timeout`. If the state still does not match, `tisutil` MUST exit
> with code `1`. For an enable without `--force`, the message MUST say that
> the user may have denied or not answered the prompt. An unapplied forced
> enable MUST report that the source is still not enabled without suggesting
> that a prompt was shown.

> [spec:tis:req:mutate.force-enable+2]
> In a login session, `tisutil enable --force <id>` MUST request enablement
> without the macOS approval sheet by resolving the private
> `TISEnableInputSourceWithOptions` function at runtime and passing option
> bit `2`. Without `--force`, commands
> MUST use the public enable function. An already enabled source MUST succeed
> without an enable call. If the private function is unavailable, the command
> MUST fail with exit code `1` and name the missing function.
>
> For a target user without a GUI session, `enable --force` MUST record
> enablement through the preference fallback in `session.prefs-fallback`,
> including for third-party sources, without requiring user approval.
>
> `select --enable`, `register --enable`, `register --select`,
> `install --enable` and `install --select` MUST accept `--force` and use it
> for every required enable. Other combinations MUST reject `--force` with
> a usage error. A root system install MUST forward it to the registration
> command in the target user's session. Every forced enable MUST follow
> the normal lookup, main-actor isolation and post-change verification rules.
> Help and documentation MUST describe that `--force` skips the macOS
> approval sheet without exposing implementation details.

> [spec:tis:req:mutate.layout-override]
> `tisutil override` MUST print the keyboard layout override of the current
> input method (`TISCopyInputMethodKeyboardLayoutOverride`).
> `tisutil override <id>` MUST set it (`TISSetInputMethodKeyboardLayoutOverride`)
> and MUST refuse a source whose type is not a keyboard layout.
