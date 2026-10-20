# Dictation

macOS dictation is an input source in TIS, with its settings kept in
preferences. These rules cover what `tisutil` reports about it.

> [spec:tis:def:dictation.source]
> Dictation is the input source `com.apple.inputmethod.ironwood`, a source in
> the palette category named "Dictation".

> [spec:tis:req:dictation.status+1]
> `tisutil dictation status` MUST print whether dictation is on, as
> `assistantd` reports it through `AFPreferences` (`dictationIsEnabled`); the
> dictation language (`DictationIMLocaleIdentifier`); whether the Dictation
> input source is installed, enabled and selected; and whether dictation
> auto-enable is on, as TIS reports it (`TISGetDictationShouldAutoEnable`).
> Any of these that cannot be read MUST be reported as unknown rather than
> guessed. With `--json` it MUST print one JSON object.

> [spec:tis:req:dictation.languages]
> `tisutil dictation languages` MUST list every locale in `Offline Dictation
> Status` in the `com.apple.assistant.support` preferences, with whether its
> on-device model is installed and each of its other flags as macOS records
> them. With `--json` it MUST print one JSON array.

> [spec:tis:req:dictation.auto-enable]
> `tisutil dictation auto-enable` MUST print whether dictation auto-enable is
> on. `tisutil dictation auto-enable on|off` MUST set it through
> `TISSetDictationShouldAutoEnable`, read it back with
> `TISGetDictationShouldAutoEnable`, and exit with code `1` if it did not
> change. If either function is unavailable, the command MUST exit with
> code `1` and name it.

## How macOS stores dictation settings

Observed on macOS 26.5 by watching what System Settings → Keyboard →
Dictation writes. These notes are background for the rules, not rules.

| Setting | Where | Written by |
|---------|-------|------------|
| Dictation on/off | `Dictation Enabled` in `com.apple.assistant.support` | `assistantd`, on request from System Settings |
| Auto-enable | `AppleDictationAutoEnable` in `com.apple.HIToolbox` | HIToolbox, set to on when dictation is turned on |
| Dictation language | `DictationIMLocaleIdentifier` in `com.apple.speech.recognition.AppleSpeechRecognition.prefs` | the Dictation input method |
| Languages offered | `VisibleNetworkSRLocaleIdentifiers` in the same domain | System Settings |
| On-device models | `Offline Dictation Status` in `com.apple.assistant.support` | `assistantd` |

`assistantd` owns `Dictation Enabled`. System Settings changes it through
the private `AFPreferences` class in AssistantServices
(`setDictationIsEnabled:`), which also offers `dictationIsEnabled`,
`activeDictationLanguages` and `offlineDictationStatus`. Reading works from
any process, but `assistantd` refuses changes from a process without the
private entitlement `com.apple.private.assistant.settings`, so `tisutil` can
report whether dictation is on but cannot turn it on or off. Writing the
preference directly would bypass `assistantd`.

Turning dictation on in System Settings also asks whether to share audio to
improve Siri and Dictation, and the Dictation input method shows a privacy
introduction the first time it is used (`DictationIMIntroMessagePresented`).
`AFPreferences` has a `setSuppressDictationOptIn:` that `tisutil` does not
use.

Turning dictation on and off did not write any TIS preference other than
`AppleDictationAutoEnable`. The Dictation input source
(`com.apple.inputmethod.ironwood`) was disabled before and after; its TIS
state while dictation was on was not observed.

`TSMSelectDictationLanguage` and the other `TSMProcessIronwoodSessionAction`
functions act on the dictation session of the focused text input document,
so they do nothing useful from a command-line tool.
