# bjarkiLearn

A shared Lua learner for the Bjarki World of Warcraft addon suite. It combines readable encounter context with a small predictive model and revisable training records.

**Status: 0.2.0-long-memory-shadow (experimental branch).** The prior 0.1.6 behavior is preserved while a bounded, deidentified long-term rehearsal bank and an optional validated serving checkpoint are added. The new code has dedicated Lua regressions; native client validation, CPU profiling, and predictive usefulness remain pending.

The addon starts in shadow mode. It records evidence and trains real models; its forecasts remain diagnostics. The suite's tracking, colours, layout and aura priorities keep their existing owners and behavior.

**[Complete design](DESIGN.md)** · **[Current behavior and API](docs/API.md)** · **[Verification](VERIFICATION.md)**

## Install and inspect

Extract the install ZIP so `Interface/AddOns/bjarkiLearn/` contains `bjarkiLearn.toc` directly, enable the addon, then reload. Both ordinary and Camelot manifests target Interface 16001, matching the supplied Forever v16 suite. No extra library is required. The other three suite addons are optional dependencies.

| Command | Result |
| --- | --- |
| `/blearn status` | Label coverage, model progress, paired prediction losses, bridge status and available CPU measurements |
| `/blearn inspect player` | Current semantic context, class candidates and supported shadow scores |
| `/blearn inspect target` or `focus` | Actor context and candidates; enemy learned scores remain withheld |
| `/blearn disable` / `enable` | Pause or resume collection and learning, retaining examples |
| `/blearn reset` | Clear only this addon's retained examples and adaptation |

`/bjarkilearn` is an alias. Play normally: eligible windows open during known combat, and bounded training runs after combat. There is no new display frame or configuration panel.

## What 0.1 implements

The first task is **registered readable cast-family deliveries in the next two seconds**. Six heads classify fear, stun, root, silence, interrupt and defensive ability use. These labels do not establish landed effects, successful interruption, actual cooldown readiness or complete hidden enemy activity.

| Component | Implemented behavior |
| --- | --- |
| Semantic context | Readable player/target/focus identity, class, role, combat, health, power and supported Druid form witnesses |
| Capability rules | Provisional class candidates before spells happen; Priest fear is relevant and Silence stays conditional |
| Portraits bridge | Existing positive-aura protocol supplies identified Barkskin/Evasion witnesses, with revisions, bounded replay and no cast-label inference |
| Neural candidate | 48 inputs, 12 tanh hidden units, six sigmoid outputs: **666 trainable parameters** |
| Comparators | Regularized logistic model and Laplace-smoothed event frequencies on the same eligible examples |
| Learning lifecycle | Immutable anchors, per-output masks, deduplication, replacement of revised outcomes and deterministic clean rebuilds |
| Limits | 16 actors, 128 occurrences, 256 recent examples, **128 archived examples** (six 16-entry positive buckets plus 32 background), and up to 256 serving correction descriptors; at most 256 training rows and four sample updates per scheduled tick outside combat |

The initial negative-label regime is the local player's continuously serviced readable event stream. Combat establishes eligibility at the anchor; an already opened two-second horizon can finish after a known combat exit. Registration failure, lost identity, unknown combat, unreadable relevant events and scheduler gaps censor absence labels. Enemy positives are tracked separately, and enemy examples never train the player model.

A head needs at least two player positives and eight negatives in the completed serving model's training snapshot before numeric shadow scores are exposed. This is a support floor, not a calibration result. Sparse families can remain withheld. The initial explicit spell vocabulary is in [docs/API.md](docs/API.md).

Accepted future-dated casts stay in the same bounded registry. Context and forecast inputs use only evidence at or before their observation time, retaining an earlier valid witness when a later one is still in the future. A future cast becomes a positive outcome only after the observed clock reaches its complete timing interval. Corrections retain their existing authority; delayed maturity also checks serving-model dependencies after replay-row eviction. No additional identity queue or timer is introduced.

Forecast inputs and comparator predictions are saved before outcomes. An event at the anchor cannot predict itself. A correction replaces affected labels and evaluation contributions, invalidates the affected adaptive generation, and schedules a clean replay of valid retained examples. Retiring examples or occurrences updates the next replay without interrupting an otherwise valid completed model. That model can retain older training influence until a replacement finishes outside combat. A bounded registry remembers its unsealed training windows, so late corrections invalidate it even after their replay rows have been evicted. Evicted occurrence dependencies become unknown in replay labels; a retirement time floor prevents stale evidence from restoring superseded labels. Actor-capacity pressure briefly pauses new windows to prevent overlapping lessons after actor recreation.

Forecasts and core status expose `modelCorpusRevision`, `corpusRevision`, `modelExamples` and `modelRefreshPending`. Core status also exposes `modelDependencyCount`. The refresh flag indicates a serving snapshot differs from current replay history; it does not promise a completion time. Sustained combat or changing history can delay replacement indefinitely. Retained evaluation counts may therefore differ from the serving model's support.

`bjarkiLearnDB` stores enabled state, recent deidentified examples, the stratified long-term rehearsal archive and (only when its source corpus matches) an optional model checkpoint. Reload discards pending windows, actor bindings and raw occurrence IDs, and either restores the validated snapshot or rebuilds deterministically from the bounded corpus. It does not claim to resume an interrupted optimizer step. No player GUIDs, raw cast IDs or names are saved in examples. Restore accepts a plain dense array of up to 256 valid records; malformed arrays are rejected before replacing live state.

**Upgrading from any 0.1.x version:** saved learning is incompatible with schema 2 and is not loaded. The enabled/disabled setting carries over. A chat notice and `/blearn status` explain the rejection; new observations build a fresh corpus. This is necessary because old root negatives and the age of old defensive witnesses cannot be reconstructed from deidentified examples. New 0.2 examples and rehearsal archive can be saved and rebuilt normally.

Long-term rehearsal accepts **only deidentified examples sealed by a previous session boundary** when those examples leave the 256-row recent history. Evicted same-session rows are dropped if they remain revisable. Seven deterministic reservoirs protect space for each rare positive family and for background examples. A clean completed model can be saved as a validated snapshot cache; its full bounded training corpus is retained for deterministic rebuilds. This is bounded cross-session retention, not an irreversible lifetime-weight accumulator or a guarantee that every session contributes. The archive stores no GUIDs or raw occurrence IDs; it cannot receive late corrections across a session boundary. New training is built from up to 128 archived plus the latest 128 eligible recent examples, so the 256-row work bound remains.

The addon measures update time when the client exposes a profiling clock. Training stops after its current sample if that clock exceeds a 1.5 ms soft budget. One sample cannot be preempted; actual client performance still needs measurement.

## Purpose

Use the meaning behind the suite's existing class, ownership, form, aura, and control rules to establish what may be possible before an event occurs. Learn contextual forecasts from eligible observations while keeping confirmed events, inferred state, and predictions distinguishable.

A small neural candidate must demonstrate value against explicit rules, empirical estimates, and a linear or logistic baseline. Each enabled consumer must show a practical benefit within its runtime allowance.

## Longer-term suite roles

| Component | Role |
| --- | --- |
| bjarkiUI | Supplies readable actor identity, class, ownership, and relationships. |
| bjarkiPortraits | Supplies readable effects and supported state witnesses. |
| bjarkiCC | Supplies occurrence history, recipient DR state, timing evidence, and corrections. |
| bjarkiLearn | Maintains shared context and hypotheses, learns forecasts, and serves narrow consumer projections. |

The first adapter reads native semantic facts directly and consumes Portraits' existing bridge. CC does not yet expose its private DR model to this addon. The owning addons retain authoritative state and presentation rules; future shared projections and consumer changes need separate integration and evaluation.

## Design commitments

- Keep capability, availability, and recipient effect separate.
- Preserve occurrence identity and provenance through corrections, including revisions to training examples.
- Ground labels in qualifying observations; coverage gaps remain unknown.
- Keep evidence intake and correction available when forecasts are low, withheld, or using fallback.
- Bound records, training history, and work per update; profile on the actual client.
- Verify corrected state, subsequent consumer use, and timely propagation before enabling behavior.

## Development sequence

1. Build the context and occurrence contracts.
2. Record observations and forecasts in shadow mode.
3. Establish which output families have usable labels.
4. Compare the candidate models on held-out encounters and bounded replay.
5. Enable one narrow consumer behavior after it meets the declared prediction, practical-benefit, and preservation criteria.

The current release implements the context, recording, revision, model and diagnostic stages. Live sessions must establish usable labels and comparative value before a consumer is enabled. The recommended first consumer remains a narrowly selected CC interpretation.

## Run verification

From a checkout of this feature branch, run the new long-memory checks with both supported Lua engines:

```sh
lua5.1 tests/long_memory.lua
lua5.4 tests/long_memory.lua
```

The branch also includes a GitHub Actions workflow for syntax compilation and these regressions. When both Lua jobs pass, it publishes a minimal **installable shadow-mode ZIP** as a workflow artifact; the historical 0.1.6 ZIP is not this build. The separate 0.1.6 verification bundle documents the *previous* release and is not evidence that 0.2 has passed all earlier native simulations.

The new tests exercise the actual bootstrap, rules, network and core source, including reservoir invariants, schema rejection, snapshot restore, tamper fallback and retraining bounds. They do **not** exercise live WoW APIs or the old 0.1.6 harness. [docs/LONG_MEMORY.md](docs/LONG_MEMORY.md) explains the new contract; [VERIFICATION.md](VERIFICATION.md) retains the older release's verification record.
