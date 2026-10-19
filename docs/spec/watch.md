# Watching for changes

> [spec:tis:req:watch.stream]
> `tisutil watch` MUST observe `kTISNotifySelectedKeyboardInputSourceChanged`
> and `kTISNotifyEnabledKeyboardInputSourcesChanged` on the distributed
> notification center. It MUST print one event per notification until it
> is interrupted. A selection event carries the newly selected source. An
> enablement event carries the full set of enabled sources.

> [spec:tis:req:watch.json-lines]
> With `--json`, `watch` MUST print each event as one JSON object on its own
> line, and MUST flush stdout after every event. Input sources inside an
> event follow the shared JSON shape.
