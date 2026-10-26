# Changes

## 0.2.0-long-memory-shadow (experimental)

- Preserve a bounded, deidentified cross-session replay archive: 16 slots for each of six positive cast families and 32 for background examples. Deterministic independent per-family reservoir sampling and immutable training input copies.
- Archive only sealed examples from a prior session when they leave the 256-row recent history. Drop revisable same-session evictions instead of converting possibly correctable labels into permanent learning.
- Train from up to 128 archive examples and the latest 128 eligible recent examples; retain the existing maximum of 256 replay rows, four epochs, and out-of-combat execution.
- Save an optional validated frozen serving model when it matches the full bounded training corpus. Restore an exact matching snapshot after reload; a malformed snapshot falls back to clean replay rather than rejecting valid retained evidence.
- Validate the archive, reservoir counters, RNG state and a deterministic corpus signature before any state mutation. Change schema/compatibility to reject 0.1.x learning while keeping the enabled setting.
- Add archive and checkpoint diagnostics. No change to visual consumers, enemy negative-label policy, native event subscriptions, or the original 48 feature meanings.
- Add Lua 5.1/5.4 regression and syntax-check workflow. Live Forever profiling, compatibility and predictive benefit remain unverified.


## 0.1.6-shadow

- Recognize all six registered Entangling Roots cast ranks and add the Druid root class candidate. Nature's Grasp activation and triggered roots remain outside the cast vocabulary.
- Give defensive-witness inputs distinct meanings: eight-second recency and eligible positive evidence known. Missing, future, expired or older evidence remains unknown; exact age eight has zero recency with known evidence.
- Version the feature meanings, ruleset and cast-delivery target. Reject older saved learning before replacing live state, preserve enabled/disabled settings, and report rejected startup learning in chat and status. The public protocol and saved table shape remain unchanged.
- Preserve correction/retraction, time-floor protection, immutable inputs, replay and serving-model invalidation, and all existing record limits. Verify against the exact 0.1.5 archive, including clean replay under changed inputs.

## 0.1.5-shadow

- Remove unused per-actor history and defensive-witness mirrors. The bounded occurrence registry remains the evidence authority, and public context/feature projections retain their time-specific behavior. Actor revisions and forecast invalidation keep the same event ordering.
- Separate evidence-change, history-retirement and observed-time reconciliation entrypoints around one shared outcome updater. Corrections withdraw affected serving models; routine forgetting preserves completed models; future evidence matures only through observed time. The outcome updater does not dirty solely for lead changes; existing correction guards can still withdraw a dependent model.
- Preserve the 16-actor, 128-occurrence, 256-example and 256-serving-descriptor limits, compatibility key, saved format and correction rules. No time-field renaming, dependencies or polling are added.
- Include cross-version differential checks against the exact 0.1.4 archive, original regression sources, explicitly adapted private-cache assertions and independent review evidence in the verification bundle.

## 0.1.4-shadow

- Project cast history and defensive witnesses at the requested time, preserving earlier eligible evidence when a later record is future-dated. Future evidence cannot enter an earlier anchored input.
- Expire cached forecasts at the next relevant evidence timestamp and withhold projections queried before their own anchor.
- Admit positive outcomes only once their full timing interval has been observed. Later maturity reconciles unsealed capacity-retired rows and serving-model guards, including after replay-row eviction. Early resets censor future positives; clock rollback preserves already observed positives.
- Preserve correction/retraction authority, immutable input vectors, deterministic reset order, normal native deliveries between ticks, and all existing history limits. Future records share the existing 128-record registry.
- Keep the saved compatibility key and feature meanings; previously sealed/deidentified examples cannot be retroactively reconstructed.

## 0.1.3-shadow

- Resolve pending session-reset windows in the existing first-seen actor order, matching normal ticking. Identical ordered inputs now retain the same FIFO history and rebuild the same model across fresh Lua runtimes.
- Preserve observed positives, censor uncertain absence at reset, seal and deidentify completed examples, and retain correction handling and all history caps. No saved-schema or compatibility change.
- Add core and native lifecycle regressions, the original capacity reproduction, and repeated full-state replay comparisons on Lua 5.1 and 5.4.

## 0.1.2-shadow

- Treat explicit failed or unreadable event-registration results as failures. Preserve clients that return nil on success; unavailable cast-stream coverage censors absence while retaining readable observed positives.
- Reject malformed, sparse, oversized or metatable-backed saved-example collections before replacing live state. Valid dense saves and empty saves retain their existing meaning.
- Normalize custom seeds consistently across Lua 5.1 and 5.4 throughout the existing accepted integer range. Preserve the default initialization exactly.
- Preserve the 0.1.1 forecast continuity repair, correction handling, bounded history, combat deferral and shadow-only authority.

## 0.1.1-shadow

- Keep the last completed shadow model through routine example and occurrence retirement; rebuild from the bounded recent corpus outside combat.
- Preserve immediate correction invalidation after training rows have been retired, using at most 256 transient serving-window descriptors. Check both sides of actor/time changes and retain conservative handling of lost or stale history.
- Expose serving snapshot revision, example count and pending refresh state in copied forecast/status projections, with dependency count in core status.
- Preserve the 16-actor, 128-occurrence and 256-example caps, existing session sealing, player-only support, shadow-only outputs, combat deferral and saved-example compatibility.
- Add focused retention/correction tests and sustained full-history integration verification on Lua 5.1 and 5.4. See VERIFICATION.md and the separate reproducibility bundle.

## 0.1.0-shadow

- First installable optional addon, with ordinary and Camelot manifests for Interface 16001.
- Native readable semantic context for player, target and focus; provisional class candidates; optional existing Portraits positive-aura bridge.
- Six-head 48–12–6 neural candidate, regularized logistic comparator and event-frequency comparator.
- Immutable forecast anchors, per-head coverage masks, native occurrence deduplication, revisable outcomes and deterministic clean replay after corrections.
- Explicit player-stream learning regime; enemy absence remains unknown and enemy learned scores remain withheld.
- Bounded actors, occurrences and retained examples, combat training deferral, atomic finite updates and deidentified compatible persistence.
- Read-only copied diagnostics, slash commands and measured-update reporting when a profiling clock is available.
- Lua 5.1/5.4 regression suite, 1,100-cycle capacity replay and synthetic adaptation/restart controls.

This is a shadow release. Live-client validation, probability calibration, practical consumer benefit and changes to suite presentation remain pending.
