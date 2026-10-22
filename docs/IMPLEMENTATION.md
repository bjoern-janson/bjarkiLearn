# First learner implementation

## Goal and release boundary

Ship an installable, optional Lua addon that maintains semantic actor context, records revisable evidence, and learns a small anticipatory model in shadow mode. Existing CC tracking, portrait election, colours and layout retain their current owners. No consumer receives authority to change behavior in this release.

The initial executable task is **registered readable cast-family deliveries in the next two seconds**, version `cast-delivery-v1`. The six families are fear, stun, root, silence, interrupt and defensive ability use. A cast-family delivery does not establish a landed effect, successful interruption, ability readiness or complete hidden enemy activity.

Negative-label coverage is enabled only for the local player's continuously serviced event stream, with readable identity and successful event registration. Windows open during known combat. Their full horizon continues through known combat exit while the stream remains covered; the opening trigger need not recur. Enemy windows retain positive evidence and unknown absence. They do not train the player model or inherit its evaluated support. Unreadable events, identity changes, registration failure and scheduler gaps censor affected absence labels. Aura snapshots never certify absence or become cast labels.

## Modules and contracts

| File | Responsibility |
| --- | --- |
| `Bootstrap.lua` | Versioned contracts, caps, readable-value boundary, bounded copy helpers |
| `Rules.lua` | Explicit cast vocabulary and provisional class candidates; fixed 48-feature encoding |
| `Network.lua` | Deterministic 48–12–6 neural network, logistic comparator and frequency comparator |
| `Core.lua` | Actors, immutable window inputs, occurrence revisions, labels, saved predictions, bounded replay and persistence |
| `Adapter.lua` | Three native unit bindings, cast events and optional unchanged Portraits evidence protocol |
| `Main.lua` | Lifecycle, work scheduling, diagnostics and copied public projections |

The namespace is private. The public `BjarkiLearn` interface returns copied status, context and forecasts; it has no general evidence-injection or suite-mutation method. `OptionalDeps` supplies convenient load order without making the suite mandatory.

`Core.New()` owns the collection lifecycle. `Context(record)`, `Cast(record)`, `Aura(record)`, `Gap(reason, actor)`, `Tick(now, inCombat)`, `Forecast(actor, now)`, `Status()`, `Export()` and `Restore(saved)` operate on ordinary normalized data. Native inputs pass through the adapter's readable checks first. Actor identities and occurrence identities are session-local and never enter network features or saved variables.

Models expose `New(inputs, hidden, outputs, seed)`, `Predict(x)`, `Learn(x, y, mask, recordStatistics)`, `Valid()` and `Copy()`. The fourth Learn argument suppresses duplicate frequency counts on later replay epochs. All models see the same eligible examples and masks.

## Bounded lifecycle

- At most 16 actors, 128 evidence occurrences and 256 retained examples; at most one unresolved window per actor.
- Windows are nonoverlapping, `(anchor, anchor + 2]`, followed by a 0.25-second reconciliation delay. Inputs and all comparator predictions are saved at the anchor.
- A positive label needs an actor-attributed new cast occurrence wholly inside the window. An uncertain interval crossing a boundary censors that family. Other families need their own continuous coverage for negatives.
- Occurrence revisions replace prior evidence. Affected retained labels and evaluation contributions are recomputed; superseded examples are never added as additional events.
- If an occurrence needed by retained labels must be evicted, dependent windows are censored. If a correction can no longer be reconstructed, affected learned state is invalidated and rebuilt from the retained clean corpus.
- Retiring cast evidence advances a monotone time floor including all accepted historical revision times. Unknown identities at or before that floor cannot resurrect retired evidence. Retiring a pending actor pauses new windows through its resolve time, preventing overlapping lessons after recreation.
- Candidate training uses deterministic, ordered replay from a fixed initialization, in small steps outside combat. It replaces the published shadow model only after a complete finite rebuild. Correction invalidates old adaptive scores immediately. Ordinary new data may leave a valid previous shadow model available while rebuilding.
- Saved variables contain only compatible deidentified examples and aggregate diagnostics. Reload explicitly discards pending windows, actors, identities and training position, then deterministically rebuilds from saved examples. This is a clean restart, not an assertion of uninterrupted optimizer equivalence.

## Feature meanings

48 fixed inputs: nine class indicators plus class-known; self/hostile/friendly role; combat value and known; health fraction and known; power fraction and known; six recent-cast values and six history-known indicators; six class-association indicators and six conditional-association indicators; cat/bear/form-known; recent positive defensive witness and witness-known. Missing values remain distinct from zero observations. No RGB values, names, raw IDs or future corrections enter a saved input vector.

Class associations are versioned provisional candidates under the existing Forever foundation. They are not exhaustive exclusions or numerical priors. Priest fear is relevant immediately; Silence remains conditional. Effects on an actor do not establish the class or identity of their source.

## Validation and acceptance

1. Test numeric models before implementation: learn interacting features, mask outputs, reject invalid updates atomically, deterministic replay/copies and finite parameters.
2. Test core chronology: duplicate IDs, distinct occurrences, anchor exclusion, uncertain boundaries, per-family censorship, actor changes, late replacement, eviction, immutable inputs, pre-update scoring and clean rebuild.
3. Test native adapter using modeled APIs: secret-value boundary, optional dependencies/load order, bus replay, player-only coverage, missing fields, world resets, registration failure and combat training deferral.
4. Run every new suite and compile every runtime Lua file under Lua 5.1 and 5.4. Run a bounded long replay and retained-learning/correction replay. Independently review source and tests.
5. Produce an addon ZIP plus reproducible source/tests and a report. Clearly distinguish synthetic verification from live-client validation and predictive usefulness, both still pending.

## Execution ledger

- [x] Inspect current draft and v16 integration boundaries.
- [x] Choose standalone adapter and explicit cast-delivery target.
- [x] Establish isolated branch and test harness.
- [x] Numeric models and tests.
- [x] Context, windows, revisions, replay and persistence.
- [x] Native adapter and diagnostics.
- [x] Independent review, complete verification and installable package.

## Decisions

The existing CC namespace is private and its timing/DR pathways are sensitive. This release therefore needs no CC source patch. It consumes the existing positive aura protocol without changing its schema. Recipient DR projections, learned timing calibration, recovery-policy selection and consumer behavior remain subsequent increments with their own evaluation contracts.
