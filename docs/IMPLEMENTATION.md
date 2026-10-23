# First learner implementation

## Goal and release boundary

Ship an installable, optional Lua addon that maintains semantic actor context, records revisable evidence, and learns a small anticipatory model in shadow mode. Existing CC tracking, portrait election, colours and layout retain their current owners. No consumer receives authority to change behavior in this release.

The initial executable task is **registered readable cast-family deliveries in the next two seconds**, version `cast-delivery-v2` (expanded from v1 in 0.1.6). The six families are fear, stun, root, silence, interrupt and defensive ability use. A cast-family delivery does not establish a landed effect, successful interruption, ability readiness or complete hidden enemy activity.

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

- At most 16 actors, 128 evidence occurrences and 256 retained examples; at most one unresolved window per actor. The serving generation retains at most 256 correction descriptors containing only actor, anchor and deadline, not another copy of features, labels or occurrences. The existing candidate holds at most 256 replay rows and has no second descriptor registry.
- Windows are nonoverlapping, `(anchor, anchor + 2]`, followed by a 0.25-second reconciliation delay. Inputs and all comparator predictions are saved at the anchor.
- A positive label needs an actor-attributed new cast occurrence wholly inside the window. An uncertain interval crossing a boundary censors that family. Other families need their own continuous coverage for negatives.
- Occurrence revisions replace prior evidence. Affected retained labels and evaluation contributions are recomputed; superseded examples are never added as additional events.
- If an occurrence needed by retained labels must be evicted, dependent windows are censored. If a correction can no longer be reconstructed, affected learned state is invalidated and rebuilt from the retained clean corpus.
- Retiring cast evidence advances a monotone time floor including all accepted historical revision times. Unknown identities at or before that floor cannot resurrect retired evidence. Retiring a pending actor pauses new windows through its resolve time, preventing overlapping lessons after recreation.
- Candidate training uses deterministic, ordered replay from a fixed initialization, in small steps outside combat. It replaces the published shadow model only after a complete finite rebuild. Correction invalidates old adaptive scores immediately. Ordinary new data and routine history retirement preserve the last completed model while rebuilding. Retired training influence leaves the model at the next successful replacement, rather than at every buffer eviction. This is deliberately a frozen serving snapshot; prolonged combat or corpus changes can delay replacement indefinitely.
- Serving correction guards outlive their replay rows. Accepted evidence checks both old and new actor/time overlap even when no currently retained label changes. Duplicate or older revisions remain no-ops; unchanged semantic revisions preserve the model. Unknown corrections retain conservative invalidation, and below-floor evidence cannot acquire label authority. Successful publication replaces the single descriptor registry from the same-revision eligible unsealed corpus. Withdrawal clears it; session reset seals examples and removes its raw identifiers.
- Snapshot status exposes current and model corpus revisions, model example count and a refresh-pending flag. This flag compares revisions independently of whether a candidate is running, so a failed replacement does not make an older model appear current. Existing retained evaluation counters describe their own corpus.
- Session reset resolves pending windows in the existing first-seen actor order, matching normal Tick. Actors without a pending window are skipped; prior completed rows keep their order. This gives identical FIFO retirement and replay for identical ordered inputs, independent of Lua table hashing. It does not promise identical replay for different actor-discovery histories. Reset still censors absence, preserves observed positives, seals/deidentifies examples and clears session state.
- Saved variables contain only compatible deidentified examples and aggregate diagnostics. Reload explicitly discards pending windows, actors, identities and training position, then deterministically rebuilds from saved examples. This is a clean restart, not an assertion of uninterrupted optimizer equivalence.

## Feature meanings

48 fixed inputs: nine class indicators plus class-known; self/hostile/friendly role; combat value and known; health fraction and known; power fraction and known; six recent-cast values and six history-known indicators; six class-association indicators and six conditional-association indicators; cat/bear/form-known; positive defensive-witness recency over eight seconds and eligible-witness-known. Missing values remain distinct from zero observations. No RGB values, names, raw IDs or future corrections enter a saved input vector.

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

## 0.1.1 repair boundary

This repair was built from the supplied 0.1.0 install archive in an isolated directory. Functional changes are confined to Core.lua. Bootstrap and the two manifests carry 0.1.1-shadow; the vocabulary, network, adapter, scheduler, compatibility key and saved-example meanings are unchanged. Original archive and independent audit tests were preserved. The older design and implementation ledger above record the original project; the accompanying verification bundle records the tests actually rerun for this repair. No installed addon or GitHub repository was modified.


## 0.1.2 repair boundary

This repair starts from the exact 0.1.1 install archive. Main.lua now distinguishes a readable true or legacy nil registration return from an exception, false, unreadable value or unexpected type. Failed cast registration grants no absence coverage; readable observed positives remain evidence.

Core.lua validates saved-example collection shape before replacing any live state. The collection must be a plain dense array of 0 through 256 valid records. Raw-key validation rejects non-array and out-of-range keys, and the subsequent record pass rejects holes and unreadable records. A rejected restore preserves the serving model, replay candidate, pending windows, occurrence history, corpus revision and exported corpus. Valid saves retain their prior sealing and replacement behavior.

Network.lua uses a signed remainder plus a negative adjustment to normalize every accepted integer seed in [-9007199254740991, 9007199254740991]. This avoids Lua 5.1 quotient-rounding errors while preserving the constructor range, the default seed 73013, and the existing PRNG sequence for already correctly normalized seeds.

No feature, vocabulary, label meaning or saved schema changes were made, so the compatibility key is unchanged. In particular, previously stored labels cannot be retroactively proven or disproven by this registration repair. The adapter, retention/correction architecture, caps and outside-combat replay are unchanged. The separate verification bundle preserves previous tests, failing baseline reproductions, new regressions, independent review and exact-source package checks.


## 0.1.4 temporal repair boundary

The private core accepts future-dated evidence without claiming it has happened yet. Features and copied context use a pure projection of the existing occurrence registry at the requested time, choosing the latest eligible exact cast per family and eligible defensive witness. The raw retained record and revision authority remain intact. Forecast cache lifetime ends at the earliest relevant future witness; queries before a cached forecast's own time withhold numeric outputs. Window inputs remain immutable after anchoring.

A monotone observed-time watermark advances on accepted Context timestamps, Tick, and ResetSession. A cast's own timestamp and read-only queries do not advance it. Positive labels require the complete timing interval to have matured. One earliest-due scalar triggers a bounded batched reconciliation of unsealed examples and completed-model dependency descriptors. It introduces no additional raw history, identity queue, polling callback, or timer. At most the existing 128 occurrences and 256 examples/descriptors are scanned. Native Context-before-Cast delivery preserves normal events between scheduled ticks.

Early capacity retirement keeps a window's original horizon and correction authority. A retained future cast can mature into that row later; if a serving snapshot depended on a now-evicted row, its descriptor still triggers withdrawal. Reset advances through the observed old-session frontier, then seals/deidentifies rows and clears both timing scalars with the occurrence registry. Clock rollback cannot erase an already observed positive or import an unobserved future positive.

Revision replacement, unknown-history invalidation and latestEver/evidenceFloor protection remain unchanged. Evicting a far-future accepted identity can conservatively advance the time floor and censor subsequent unknown identities below it; the bounded registry cannot promise unlimited reconstruction after eviction. The patch fixes temporal leakage without weakening that replay protection. Historical deidentified inputs/labels already saved by older releases cannot be repaired from discarded raw evidence. Feature meanings and the compatibility key are unchanged.


## 0.1.5 internal refactor boundary

The occurrence registry is the single evidence authority. Actor records no longer store redundant history or defensive-witness projections. `_InvalidateActorEvidence(id)` retains the previous revision increment and cached-forecast removal at every former history-rebuild call site, including both actors after reattribution. `GetContext` and feature extraction continue to project the registry at their requested time. The standalone `Rules.Features(actor, now)` fallback remains supported for explicitly supplied evidence-bearing actors.

Reconciliation now exposes three internal entrypoints: `_ReconcileEvidenceChange(old, new)` checks correction guards and affected retained rows; `_ReconcileHistoryRetirement(old)` updates affected rows without withdrawing the completed serving snapshot; `_ReconcileTimeAdvance(since)` checks newly mature casts against serving guards and updates unsealed outcomes. All three share `_ReviseWindow`, which revises training state only when labels or masks change. A lead-time-only refinement updates the lead without changing the row revision or dirtying the corpus through the outcome updater. A timestamp correction can still withdraw a dependent serving model through the unchanged correction guards. Below-floor rejected evidence continues through the evidence-change path, not retirement.

No feature meanings, persisted fields, compatibility key, network parameters, caps, scheduling, observed-time fields or native adapters change. The exact 0.1.4 source and prior test scripts accompany the verification bundle. Tests that formerly read the removed private mirrors use explicit projection reads in disposable copies; original files and a substitution manifest remain available for inspection.


## 0.1.6 vocabulary, feature and compatibility boundary

The root cast family adds Entangling Roots ranks 339, 1062, 5195, 5196, 9852 and 9853. Druid root becomes a class candidate, without claiming readiness or a landed root. Nature's Grasp activation/proc identities remain excluded. The adapter and network are byte-identical to 0.1.5; the Core lifecycle changes only its advertised target metadata.

Inputs 47 and 48 are now eligible defensive-witness recency and known evidence. Existing projection selects the latest witness at or before the requested time, then feature extraction applies freshness and expiry eligibility; an expired newer witness does not resurrect an older witness. No new evidence mirror, queue or retained record is added. Recency is `1 - age/8` for age zero through eight, provided expiry has not been reached. An age-eight witness has `(0,1)`, while unknown evidence has `(0,0)`. Anchored vectors remain immutable through later witness correction.

The new compatibility key versions the ruleset, feature meanings and cast vocabulary together. The saved structure stays schema 1. Core's existing exact-key check rejects old learning before mutating live state; native startup retains the enabled setting and reports its failed load reason. Old negative root labels and witness age cannot be recovered from persisted deidentified rows, so no migration is attempted. Same-version saves retain deterministic rebuild behavior. Public interface protocol stays v1; forecast target and candidate basis advertise their v2 meanings.

Comparison to 0.1.5 distinguishes unchanged-input equality from intentional changes to Druid association, root labels, witness values and resulting learned parameters. Changed-input corrections are checked against clean replay of the corrected retained corpus. Historical test files are preserved and fixture adaptations are listed separately. Validation remains offline with modeled game APIs.
