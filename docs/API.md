# bjarkiLearn 0.1 interface and vocabulary

## Copied public projections

The optional global interface is `BjarkiLearn`, protocol `bjarki-learn-v1`.

```lua
if BjarkiLearn and BjarkiLearn.protocol == "bjarki-learn-v1" then
    local status = BjarkiLearn:Status()
    local context = BjarkiLearn:GetContext("target")
    local forecast = BjarkiLearn:Forecast("target")
end
```

Callers should apply their own readable-value boundary when another addon supplies a global. Methods return ordinary independent copies. Mutating a returned table cannot change learner state. There is no public evidence injection, training, model mutation or consumer authorization method.

`GetContext` and `Forecast` accept player/target/focus or a readable GUID currently bound to one of those units. Disabled/faulted collection or an unresolved unit yields `nil`. An existing incompatible global is preserved, and diagnostics report that the public interface was unavailable.

### Context

Context contains `class`, `role`, `regime`, `revision`, `observedAt`, `bound`, `fresh`, optional `combat`, `health`, `power` and `form`, family-keyed `candidates`, bounded recent `history`, and an optional `defensiveWitness` with source, timestamp and expiry. GUIDs in runtime projections are transient; they are never persisted in learning examples.

History and defensive witnesses are projected at the current query time. A retained future-dated record cannot hide an earlier eligible record. Queries return fresh copies and do not advance outcome maturity.

Candidate statuses are `candidate`, `conditional` and `unknown`. None means ready. Rules provide their basis and condition. Missing health/power/combat/form fields retain missingness; callers must not replace them with known zero values.

The 48 features encode nine classes plus class-known, three actor roles, combat/health/power value-known pairs, six recent-cast/known pairs, six candidate/conditional pairs, cat/bear/form-known and recent positive defensive witness/known. Names, raw identities and colours are excluded. A positive aura witness records recent evidence; it cannot establish complete current aura state or absence.

### Forecast

Computed forecasts include actor, `kind="forecast"`, `mode="shadow"`, `usable=false`, anchor `at`, `expires`, `horizon`, `contextRevision`, `modelVersion`, `regime`, `target="cast-delivery-v1"`, and an array of six outputs in the order below.

Known-actor forecast projections also include `corpusRevision`, optional `modelCorpusRevision` and `modelExamples`, and `modelRefreshPending`. The model fields describe the last completed training snapshot, not current retained label counts. Routine retirement preserves that snapshot while replacement waits for outside-combat replay. `modelRefreshPending=true` means the serving snapshot differs from current replay history, including if a replacement failed; it is not a scheduler progress guarantee. These fields are refreshed when a cached forecast is copied. Corrections affecting the snapshot withdraw it immediately, even when the affected replay row has already been evicted. Normal context freshness and expiry checks still apply.

Each output has a family, candidate explanation, `status`, `reason`, `usable=false` and `calibrated=false`. Supported diagnostic heads may include `score` (neural), `linear`, and `frequency`. All are scores in `[0,1]`; they are not calibrated percentage claims.

Withholding reasons include `cold_start`, `rebuilding`, `insufficient_positive_and_negative_support`, `unsupported_enemy_coverage`, `not_computed`, `stale_context`, `expired`, `context_revised`, `future_projection` and `unknown_actor`. The cache expires no later than the next retained relevant evidence timestamp; the two-second prediction horizon itself is unchanged. A query before the cached projection's own anchor withholds its scores. A stale query removes every numeric score. Consumers must check current context and expiry rather than retaining an old returned table indefinitely. **Every forecast in 0.1 has `usable=false`.**

### Status and evaluation

Status has `core` and `adapter` projections plus lifecycle status, registration failures, fault/error counts, scheduled updates and profiling availability. Core exposes bounded counts, model version, training state, gap reasons and a six-family array. It includes the snapshot fields above and `modelDependencyCount` (0-256), the count of transient window descriptors retained to guard corrections to its serving generation. No additional raw occurrence history is kept. A session reset clears these descriptors when examples become sealed; the existing sealed-history boundary is unchanged. Its family denominators cover retained player positives/negatives/censored labels and retained enemy positives. `scored` counts paired pre-outcome forecasts. Mean squared/Brier losses compare all three numeric estimators on those same labeled windows.

Adapter message counts count received qualifying deliveries; core cast counts count accepted unique occurrences. These denominators differ intentionally. Metrics describe the bounded retained evaluation corpus. They do not establish held-out performance after design tuning, enemy accuracy, probability calibration or useful UI interventions.

## Initial registered cast vocabulary

This explicit Forever foundation vocabulary classifies use of the named ability, not whether its effect landed. It is not exhaustive class mechanics, and unfamiliar spell IDs receive no guessed family label.

| Output | Registered spell IDs |
| --- | --- |
| fear | Psychic Scream: 8122, 8124, 10888, 10890; Howl of Terror: 5484, 17928; Intimidating Shout: 5246 |
| stun | Hammer of Justice: 853, 5588, 5589, 10308; Bash: 5211, 6798, 8983; Kidney Shot: 408, 8643; Concussion Blow: 12809; War Stomp: 20549 |
| root | Frost Nova: 122, 865, 6131, 10230; Counterattack: 19306, 20909, 20910, 1242634 |
| silence | Silence: 15487 |
| interrupt | Kick: 1766, 1767, 1768, 1769; Pummel: 6552, 6554; Shield Bash: 72, 1671, 1672; Counterspell: 2139; Spell Lock: 19244, 19647 |
| defensive | Barkskin: 22812; Evasion: 5277, 26669 |

Creature/pet actor collection and ownership relationships are not implemented in the first adapter. Conditional capability seeds can describe prerequisites without supplying an actor-attributed label. Unknown spell counts include ordinary abilities outside this small vocabulary, not necessarily newly discovered mechanics.

Nature's Grasp activation is excluded from root labels. The shared Shock cooldown mapping is not reused as an interrupt mapping. Aura effect IDs are not automatically interpreted as cast IDs. Defensive aura witnesses are exactly Barkskin/Evasion, require a readable native aura identity, and never label this cast-delivery target.

## Source basis and versioning

The supplied suite established the readable-value, class/form and evidence boundaries:

- [bjarkiCC v16 Data.lua](https://github.com/bjoern-janson/bjarkiCC/blob/26d0a56ebb8968736737b63327f926d8668804fb/Data.lua): explicit registered ability IDs and separate cast, effect and shared-cooldown meanings.
- [bjarkiCC v16 SharedEvidence.lua](https://github.com/bjoern-janson/bjarkiCC/blob/26d0a56ebb8968736737b63327f926d8668804fb/SharedEvidence.lua): positive helpful-aura protocol, bounded eight-second replay and copied listeners.
- [bjarkiPortraits v16 Spells.lua](https://github.com/bjoern-janson/bjarkiPortraits/blob/e0a855e2bd50418242b27a1a6b5c19d032179384/Spells.lua): explicit Silence ID.
- [bjarkiPortraits v16 AuraEngine.lua](https://github.com/bjoern-janson/bjarkiPortraits/blob/e0a855e2bd50418242b27a1a6b5c19d032179384/AuraEngine.lua): readable class/power/alive form witnesses.
- [bjarkiUI v16](https://github.com/bjoern-janson/bjarkiUI/blob/18f9a3d52f4943dee591ea6ac8efe98c2afef764/bjarkiUI.lua): readable identity semantics distinct from native opaque rendering.

The research motivation and larger future contract remain in [DESIGN.md](../DESIGN.md). Changing feature meanings, cast vocabulary or label/coverage semantics requires a new compatibility key; saved examples must not silently acquire a different interpretation.
