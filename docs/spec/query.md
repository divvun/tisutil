# Query commands

Read-only commands. None of them change TIS state.

> [spec:tis:req:query.list]
> `tisutil list` MUST print the enabled input sources. `--all` MUST also
> include sources that are installed but not enabled. The filter flags MUST
> map one-to-one onto the TISKit list filter.

> [spec:tis:req:query.current]
> `tisutil current` MUST print the current keyboard input source. Flags MUST
> select the other variants that TISKit exposes instead: the current
> keyboard layout, the ASCII-capable source, the ASCII-capable layout, or
> the source for a given language.

> [spec:tis:req:query.show]
> `tisutil show <id>` MUST print every property of the named input source.
> It MUST NOT print the raw Unicode keyboard layout data; it MUST print
> whether that data is present and its size in bytes instead.
