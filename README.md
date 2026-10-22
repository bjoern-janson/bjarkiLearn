# bjarkiLearn

A shared Lua learner for the Bjarki World of Warcraft addon suite. It combines readable encounter context with a small predictive model and revisable training records.

**Status: 0.1.0-shadow — first installable implementation.** Native API behavior is tested with modeled WoW APIs under Lua 5.1 and 5.4. Live-client validation and demonstrated predictive usefulness remain pending.

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
| Limits | 16 actors, 128 occurrences, 256 retained windows/examples; at most four sample updates per scheduled tick outside combat |

The initial negative-label regime is the local player's continuously serviced readable event stream. Combat establishes eligibility at the anchor; an already opened two-second horizon can finish after a known combat exit. Registration failure, lost identity, unknown combat, unreadable relevant events and scheduler gaps censor absence labels. Enemy positives are tracked separately, and enemy examples never train the player model.

A head needs at least two retained player positives and eight negatives before numeric shadow scores are exposed. This is a support floor, not a calibration result. Sparse families can remain withheld. The initial explicit spell vocabulary is in [docs/API.md](docs/API.md).

Forecast inputs and comparator predictions are saved before outcomes. An event at the anchor cannot predict itself. A correction replaces affected labels and evaluation contributions, invalidates the affected adaptive generation, and schedules a clean replay of valid retained examples. Evicted dependencies become unknown; a retirement time floor prevents stale evidence from restoring superseded labels. Actor-capacity pressure briefly pauses new windows to prevent overlapping lessons after actor recreation.

`bjarkiLearnDB` stores enabled state and compatible deidentified examples. Reload discards pending windows, actor bindings and raw occurrence IDs, then rebuilds from the corpus. It does not claim to resume an interrupted optimizer step. No player GUIDs, raw cast IDs or names are saved in examples.

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

```sh
python3 -m pip install -r requirements-test.txt
python3 tests/run.py
```

Tests execute the real addon code in Lupa's Lua 5.1 and 5.4 runtimes. The six runtime modules separate the readable-value boundary, semantic rules, numeric models, learning core, adapter and lifecycle. [VERIFICATION.md](VERIFICATION.md) records the release checks; [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) records implementation decisions.
