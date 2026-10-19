# Command-line conventions

These rules apply to every `tisutil` subcommand. Installers and scripts
depend on them, so they are part of the stable interface.

## Output

> [spec:tis:req:cli.output-modes]
> By default, every command MUST print human-readable output to stdout. With
> `--json`, a command MUST print exactly one JSON document to stdout instead.
> Streaming commands are the exception and follow their own rule.
> Diagnostics MUST go to stderr in both modes.

> [spec:tis:req:cli.json-shape]
> Every command that prints an input source as JSON MUST use the same field
> names and value encodings. A property that is absent MUST be printed as
> `null`, not left out.

## Exit status

> [spec:tis:req:cli.exit-codes]
> `tisutil` MUST exit with these codes:
>
> - `0` on success.
> - `1` when a TIS call or a file-system operation fails.
> - `2` when no input source matches the requested ID or filter.
> - `64` on a usage error.
> - `77` when the operation needs a privilege or a user session that
>   `tisutil` does not have.
>
> These values MUST NOT change between releases. The help text MUST list
> them.
