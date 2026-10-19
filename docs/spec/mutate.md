# State commands

Commands that change which input sources are enabled or selected.

> [spec:tis:req:mutate.enable-disable]
> `tisutil enable <id>` MUST call `TISEnableInputSource`, and
> `tisutil disable <id>` MUST call `TISDisableInputSource`. Enabling a source
> that is already enabled MUST succeed and change nothing. The same holds
> for disabling a source that is already disabled.

> [spec:tis:req:mutate.select]
> `tisutil select <id>` MUST call `TISSelectInputSource`, and
> `tisutil deselect <id>` MUST call `TISDeselectInputSource`. If the source is
> not select-capable, the command MUST fail without calling TIS. If the
> source is not enabled, `select` MUST fail unless `--enable` is given, in
> which case it MUST enable the source first.

> [spec:tis:req:mutate.verify+1]
> TIS can return `noErr` before a change takes effect, or without making it
> at all. For a third-party input source, macOS asks the user to allow an
> enable and applies it only once they do. After every enable, disable,
> select or deselect, `tisutil` MUST read the source again until its state
> matches the request, for up to 60 seconds or the number of seconds given
> with `--timeout`. If the state still does not match, `tisutil` MUST exit
> with code `1`. For an enable, the message MUST say that the user may have
> denied or not answered the prompt.

> [spec:tis:req:mutate.layout-override]
> `tisutil override` MUST print the keyboard layout override of the current
> input method (`TISCopyInputMethodKeyboardLayoutOverride`).
> `tisutil override <id>` MUST set it (`TISSetInputMethodKeyboardLayoutOverride`)
> and MUST refuse a source whose type is not a keyboard layout.
