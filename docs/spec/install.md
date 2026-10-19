# Registration and installation

Commands that make new keyboard layouts and input methods visible to TIS
without a logout.

> [spec:tis:req:install.kind-detect]
> `tisutil` MUST work out what an item is from its contents. It accepts a
> `.keylayout` file, a bundle that contains `.keylayout` resources, or an
> application bundle whose `Info.plist` declares an input method. It MUST
> refuse anything else with a usage error.

> [spec:tis:req:install.register]
> `tisutil register <path>` MUST call `TISRegisterInputSource` with the file
> URL of the item. It MUST then list all installed sources, confirm that the
> item's sources are present, and print their IDs. If none are present, it
> MUST exit with code `1`.

> [spec:tis:req:install.place]
> `tisutil install <path>` MUST copy the item into the directory that matches
> its kind: `Keyboard Layouts` for layouts, `Input Methods` for input
> methods. The default is under `~/Library`; `--system` uses `/Library`. An
> existing item with the same name MUST be replaced atomically, so that TIS
> never sees a half-copied item. After copying, `install` MUST register the
> copy as `register` does.
>
> When `tisutil` runs as root, `install` MUST copy as root, then register
> and enable in the target user's session as described for re-execution.

> [spec:tis:req:install.enable]
> `tisutil install --enable` MUST enable every source the item registered.
> `--select` MUST also select the first one. Both follow the state command
> rules, including the check that the change took effect.
