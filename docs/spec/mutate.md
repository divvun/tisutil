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

> [spec:tis:req:mutate.verify]
> TIS can return `noErr` without applying a change. After every enable,
> disable, select or deselect, `tisutil` MUST read the source again and MUST
> exit with code `1` if its state does not match the request.

> [spec:tis:req:mutate.layout-override]
> `tisutil override` MUST print the keyboard layout override of the current
> input method (`TISCopyInputMethodKeyboardLayoutOverride`).
> `tisutil override <id>` MUST set it (`TISSetInputMethodKeyboardLayoutOverride`)
> and MUST refuse a source whose type is not a keyboard layout.
