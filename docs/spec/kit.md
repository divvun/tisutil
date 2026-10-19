# TISKit

TISKit is the Swift library under the `tisutil` executable. It wraps the
Carbon Text Input Sources API (`TextInputSources.h` in HIToolbox) in value
types and typed errors. The CLI holds no TIS logic of its own.

## Input source model

> [spec:tis:def:kit.input-source]
> An InputSource is an immutable snapshot of one TIS input source. It holds
> the input source ID (`kTISPropertyInputSourceID`), category, type, bundle
> ID, input mode ID, localized name, languages, icon image URL, whether
> Unicode keyboard layout data is present, and the ASCII-capable,
> enable-capable, select-capable, enabled and selected flags.

> [spec:tis:req:kit.property-snapshot]
> TISKit MUST read every InputSource property when the snapshot is created.
> It MUST NOT keep the underlying `TISInputSourceRef` past that point,
> except where an operation needs it to call TIS.
>
> A property that TIS reports as absent MUST be `nil` in the snapshot. It
> MUST NOT become an empty string, an empty array or `false`.

> [spec:tis:req:kit.category-type]
> TISKit MUST map the `kTISCategory*` and `kTISType*` constants to Swift
> enumerations. A value not known at build time MUST be kept verbatim in an
> `unknown(String)` case. TISKit MUST NOT fail or drop the source because of
> an unknown value.

## Enumeration

> [spec:tis:req:kit.list]
> TISKit MUST list input sources through `TISCreateInputSourceList`. The
> list call MUST accept a filter on category, type, input source ID, bundle
> ID, language, enabled state and selected state. It MUST also accept a flag
> that includes sources which are installed but not enabled.

> [spec:tis:req:kit.current]
> TISKit MUST expose the current keyboard input source, the current keyboard
> layout, the current ASCII-capable keyboard input source, the current
> ASCII-capable keyboard layout, and the input source for a given language
> (`TISCopyInputSourceForLanguage`).

> [spec:tis:req:kit.lookup]
> Lookup by input source ID MUST match the ID exactly and MUST search all
> installed sources, enabled or not. When nothing matches, lookup MUST fail
> with a not-found error that carries the requested ID.

## Errors

> [spec:tis:req:kit.errors]
> Every TIS call that returns an `OSStatus` MUST turn a non-zero status into
> a typed error. The error carries the status code and the name of the TIS
> function that returned it. TISKit MUST NOT discard a failed status.
