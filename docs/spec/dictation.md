# Dictation

macOS dictation is an input source in TIS, with its settings kept in
preferences. These rules cover what `tisutil` reports about it.

> [spec:tis:def:dictation.source]
> Dictation is the input source `com.apple.inputmethod.ironwood`, a source in
> the palette category named "Dictation".

> [spec:tis:req:dictation.status]
> `tisutil dictation status` MUST print whether the Dictation input source is
> installed, enabled and selected, and whether dictation auto-enable is on, as
> TIS reports it (`TISGetDictationShouldAutoEnable`, the
> `AppleDictationAutoEnable` preference in `com.apple.HIToolbox`). If that
> function is unavailable, auto-enable MUST be reported as unknown rather than
> guessed. With `--json` it MUST print one JSON object.

> [spec:tis:req:dictation.languages]
> `tisutil dictation languages` MUST list every locale in `Offline Dictation
> Status` in the `com.apple.assistant.support` preferences, with whether its
> on-device model is installed and each of its other flags as macOS records
> them. With `--json` it MUST print one JSON array.
