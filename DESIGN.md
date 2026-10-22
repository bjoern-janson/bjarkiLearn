# Bjarki Shared Learner Design Draft

**Draft 0.11 · 22 October 2026**

The Bjarki suite should share a small model of the encounter: who the actors are, what they may be capable of, what has been observed, and which events and effects are plausible next. A neural learner running in addon Lua would use that context to improve selected forecasts as experience accumulates.

The existing colour rules are part of this foundation. Readable class, ownership, form, and unit relationships supply meaningful information before an opponent uses a spell. Portraits contributes current effects and state witnesses. CC contributes control history, occurrence tracking, and timing evidence. The shared learner brings those observations together while preserving the identity and history needed to revise an interpretation.

The first version should demonstrate an anticipatory benefit with a bounded amount of code, memory, and runtime work. The working component name is **bjarkiLearn**.

## Intended result

When a Priest becomes a known opponent, the suite should immediately have an appropriate set of candidate capabilities. Fear becomes relevant under the active ruleset; Silence remains conditional on the applicable eligibility rules and available build evidence. Subsequent observations refine expectations about what may happen next.

The shared model should answer three separate questions:

1. **Capability:** Could this actor possess this ability?

2. **Availability:** Could the actor use it within the relevant time window?

3. **Effect:** If used on this recipient, what outcomes remain plausible?

A forecast can rank those possibilities. A confirmed observation establishes that something happened. These distinctions allow the suite to prepare before an event while keeping its timers and control history grounded in the evidence available.

Success means a repeatable anticipatory benefit while preserving the tested observation and revision paths the suite depends on, within its runtime budget. Each consumer must demonstrate a concrete benefit; a better aggregate prediction score cannot compensate for a protected tracking or correction failure.

## Contributions from the existing suite

| Component | Contribution to shared context | Intended use |
| --- | --- | --- |
| bjarkiUI | Readable actor identity, class, ownership, and unit relationships | Establish candidate capabilities before a spell is observed and associate observations with the correct actor |
| bjarkiPortraits | Readable aura observations, effect classifications, and supported state witnesses such as Druid form | Describe the current conditions that modify possible actions and effects |
| bjarkiCC | Observed applications, recipient DR state, cooldown evidence, timing estimates, and corrections | Preserve the temporal context that distinguishes otherwise similar situations |
| bjarkiLearn | Joint context, capability hypotheses, and learned forecasts | Supply consistent predictions to the consumers that can use them |

The supplied foundation already contains a narrow Portraits-to-CC evidence bridge, readable class and owner resolution in UI, class-and-power form inference in Portraits, and occurrence-matched timing correction in CC. The current bridge accepts positive helpful-aura observations; identity and context records require a separately defined and validated extension. It is not a general prediction channel today. The source files and snapshot versions are listed under Source basis.

Share the readable semantic facts used by the colour rules. Class colour, name colour, and a portrait referring to one actor are related presentations of information, rather than independent confirmations. Native rendering paths that accept opaque values remain outside the learner's inputs.

Existing ownership stays clear: CC owns its DR and cooldown state; Portraits owns aura election and portrait presentation; UI owns its visual rules. The shared core owns its normalized context, hypotheses, and forecasts. Consumers request narrow projections rather than giving the learner general authority over their behavior.

## The shared encounter model

An encounter model contains actors and relationships between them. Independent actor profiles alone cannot describe an effect applied by one actor to another.

### Observed context

Each observation carries its kind, source, observation time, readable actor identity where available, and occurrence identity where available. A cast, an aura application, a first sighting, an expiration, and a timestamp correction are distinct observation kinds.

A record can have a known recipient and unknown source. Knowing that the current target is a Priest does not identify that Priest as the source of a fear observed on the player.

Related unit tokens can refer to the same actor, while pooled frames can acquire a new actor. Identity must be reconciled before history is reused.

### Capability knowledge

Maintain a compact, versioned set of relationships among:

- Classes, forms, and ability families.

- Optional build, level, race, pet, and item requirements.

- Abilities, resulting effects, and separately verified DR categories.

- Known resets, timing bounds, and relevant recipient conditions.

Seed established relationships from reviewed rules. Learning should concentrate on uncertainty and context rather than spending encounters rediscovering a known class association. Capability rules establish possibility; numerical event-rate priors require eligible observations or explicitly identified assumptions. Knowing that a Priest may fear supplies no particular probability of fear in the next two seconds.

Treat rules with different levels of support differently. A verified impossibility may exclude a candidate. An unverified Forever assumption remains provisional. Preserve a route for unfamiliar abilities, external sources, and changed rules.

The class of an actor constrains capabilities that actor may originate. It does not define every aura that may be present on that actor.

### Hypotheses and forecasts

Keep the following states distinguishable:

| State | Meaning |
| --- | --- |
| Observed | A qualifying readable observation supports the statement |
| Derived | An explicit rule supports an interpretation of observed facts |
| Hypothesized | More than one explanation remains possible |
| Forecast | A prediction about a declared future window |

A numerical forecast is not evidence that an ability is ready. Where readiness itself cannot be verified, report the relevant evidence and timing hypothesis rather than creating an exact readiness label.

DR belongs to the affected actor and category. A class prior can anticipate which categories may become relevant; it does not advance a DR stage. Casting feasibility and effect potency also remain separate: a spell may remain castable while its effect is shortened or ineffective.

### Evidence required by each output

Each consumer output and training label declares its supported context, required evidence and freshness, the state it may update, and the result when required evidence is unavailable. A high forecast score cannot authorize a different kind of update. Apply these requirements to the particular claim:

- **Candidate capabilities:** Use readable actor identity and the class, ownership, build or event evidence relevant to a versioned eligibility rule. Unresolved requirements remain conditional.

- **Cooldown estimates:** Preserve ability and source association, uncertainty in occurrence timing, and applicable cooldown, charge and reset rules. Estimated readiness retains its uncertainty; an exact readiness claim requires those assumptions to establish it.

- **Event forecasts:** Use the required readable fields and explicit unknowns in the actor/context snapshot at the anchor, with a declared event family, horizon and observation regime. Optional missing inputs remain permitted in evaluated regimes; calibration determines whether a score can be presented as a probability.

- **Occurrence revisions:** Preserve the association with the existing occurrence, evidence provenance, current revision and dependent training examples so a correction reaches the affected state without creating a new application.

- **Negative labels:** Require coverage capable of establishing absence for that family over the window, with actor association and event-time precision sufficient for the declared target and horizon. A coverage gap leaves the affected output unlabeled.

Keep readable observations, rule-derived context, and model-derived outputs distinguishable across addon routes. A prediction, a presentation change caused by it, or a downstream report of that change cannot serve as independent confirmation or an outcome label. Labels must be grounded in qualifying observations whose provenance does not depend on the forecast being evaluated.

## The neural prediction task

The first neural task is: **For this identified actor, which event families will have at least one verified new occurrence attributable to that actor during the next short window?** This predicts event occurrence in a declared observation regime. It does not claim access to every hidden action. A **two-second horizon** is the starting design choice. It can be changed through evaluation before a model is enabled for consumers.

An initial output vocabulary could cover fear, stun, root, silence, interrupt, and defensive self-effect observations. These are prediction families. Their classification must come from explicit event definitions; a broad portrait priority group is not automatically an exact event or DR classification.

Use one output per family, asking whether at least one qualifying event of that family occurs within the window. Several outputs can be true. This avoids assuming that one visible event establishes which event happened first in a partly observed encounter.

Every prediction is made from a snapshot available at its anchor time. The event that triggers a new forecast belongs to the history; its own occurrence is excluded from the future window. Later timestamps, corrections, and outcomes cannot leak into that input snapshot.

Useful inputs include readable class, supported form, ownership or actor role, recent verified event summaries, elapsed times, relevant recipient DR state, known timing bounds, and explicit missing-data flags. Missing information has its own representation. An unknown cooldown is not encoded as a ready cooldown.

### A small starting architecture

Use shared weights across tracked actors and a compact explicit history summary. A feed-forward network can use that summary without requiring a recurrent neural state in the first version.

An illustrative capacity budget is:

- Up to 64 normalized or categorical input features.

- One hidden layer with 16 units.

- Six sigmoid outputs, one per event family.

That configuration has **1,142 trainable weights and biases**. It is a proposed starting size, not a performance result or a fixed feature specification. The feature inventory and label availability should determine the final shape.

The model estimates contextual associations. Predictions under hypothetical player actions are scenarios; observational training alone does not establish the causal effect of choosing an action. The rule layer retains established identity, capability, and event semantics. An uncertain capability remains eligible for learning; a verified mechanical exclusion is applied explicitly and retains its reason.

Until evaluation establishes calibration for a particular observation regime, outputs are ranking scores. Percentage labels require evidence that those probabilities are calibrated in the contexts where they will be used.

### Forecast contract

A forecast includes the relevant actor and recipient relationship, event family, time horizon, context revision, model version, expiry, and whether the score is usable or withheld. It also exposes the observation regime, the evidence or rule that constrained its candidate set, and the freshness and coverage needed by its consumer. Preserve unresolved alternatives when they could change that consumer's decision. The highest-ranked candidate is not necessarily a uniquely established explanation; withheld alternatives remain unknown.

Each consumer applies explicit acceptance checks with compact withholding reasons. Missing or stale required evidence, a decision-relevant contradiction, unsupported context, expiry, or a revision mismatch disqualifies that forecast. Optional missing inputs remain usable in evaluated observation regimes. When inference is deferred to respect its budget, a current valid cached forecast may still be used; otherwise use the owning addon's established fallback. Exhausting the training allowance defers learning without invalidating an otherwise eligible forecast. These decisions use information available to the consumer.

Recompute after meaningful context changes or a bounded clock update when elapsed time changes the inputs. Consumers use a cached forecast for the current context. They do not run separate copies of the network.

## A Priest encounter

1. **Identity becomes readable.** UI supplies a Priest identity attached to the current actor. The shared rules establish relevant candidate capabilities. Silence remains an unresolved possibility until the rules and evidence justify a stronger claim.

2. **The model anticipates.** Current context and history produce forecasts for the declared event families. The suite can prepare the relevant tracking state before an event occurs.

3. **A fear effect is observed.** Record the affected actor and the occurrence. Link a source only when the available evidence supports it. A qualifying application updates the recipient's CC state once; first sighting of an already active effect retains timing and history uncertainty.

4. **The future changes.** The control event can alter the recipient's possible responses and the effectiveness of a later application under the active DR rules. A cast may remain feasible even when its expected effect changes.

5. **Timing is corrected.** A later readable timestamp updates the existing occurrence. It changes dependent estimates without manufacturing a second application.

6. **The visible effect ends.** The model retains the compact history needed for later DR and timing interpretation. A clear portrait does not by itself imply that every consequence of the earlier effect has cleared.

This example is the behavior the first design should support. Exact eligibility, durations, and DR rules come from the active verified ruleset.

## Revision and learning from corrections

Occurrence identity is central to both tracking and training. A repeated sighting, a refresh, a new application, and a correction of an existing application must remain distinguishable to the extent the observations support them.

For each active occurrence, retain enough provenance to answer what was observed, what was inferred, which interpretation is current, and which later evidence changed it. The literal identifier may be remapped if the causal relationship survives. Keep evidence metadata separate from neural input features. An occurrence identifier, provenance link or revision dependency can be necessary for correction even when it has no predictive value. Feature removal must preserve the metadata required by the bounded correction and replay policy.

The same discipline applies to training records. A corrected outcome replaces the relevant version of one example. It does not become a second example of the event occurring.

If a label changes after it has contributed to learning, remove the superseded example from replay and rebuild the affected candidate model from a known checkpoint and the valid retained examples. An opposite gradient step is not assumed to undo a previous update exactly. If the bounded history is insufficient to reconstruct a clean model, invalidate that adaptive generation and return to the rule/statistical baseline while a clean candidate is rebuilt.

To resume the same training process, restore model parameters and the update state actually used: optimizer state, random generator state, counters, pending windows and examples, buffers and update order, where applicable. Verify restoration against uninterrupted execution of the same ordered replay stream, including pending-window resolutions, using declared numerical tolerances and exact discrete transitions. Replaying corrected history starts before the first affected update; missing required state follows the invalidation and rebuild policy. Frozen inference comparisons keep learning disabled.

This makes later correction an operation the design supports, including after an early interpretation has influenced learning.

## Training data and observation coverage

Training requires a declared outcome and a way to establish it. The suite does not get a complete record of all combat events merely by combining addons.

For each output family:

- A verified new occurrence with sufficient actor attribution and event timing inside the window can label that family as present.

- An absent-event label requires an observation regime capable of establishing that absence for that family over the window.

- A gap, unreadable interval, unresolved identity, or incomplete channel leaves that output unlabeled.

- Other outputs remain unlabeled unless their own evidence supports a label.

A positive fear observation does not prove that no silence, stun, or interrupt occurred. An unused ability does not prove that the opponent lacks it, and a later cast does not reveal the instant when its cooldown became ready.

A first sighting of an existing aura is not a fresh occurrence. A late report of an event before the anchor cannot count as successful anticipation. If event-time uncertainty crosses a window boundary, or source attribution remains unresolved, retain an unknown label for that actor's forecast.

Use per-output label masks. Record why a window was censored or unresolved and report those counts alongside accuracy. If a family never receives defensible negatives, presence examples alone do not justify calibrated occurrence probabilities. Retain a prior or withhold the learned output until the data supports the intended task.

The model's claim is restricted to its declared observation regime. Verification frequency can depend on context, so good results on readable cases do not establish the same accuracy in hidden cases.

Define training and evaluation eligibility independently of current forecast scores. If runtime limits require sampling, use an explicit policy and record its version. Apply the same eligible evaluation windows and label masks to every baseline and candidate, and report sampled-out and censored opportunities separately. A prediction must not determine which outcomes are collected or retained to judge that prediction.

### Online updates

Capture the input snapshot and prediction before the outcome arrives. Resolve the label when the horizon and allowed reconciliation period have closed. Score the saved prediction before using that example for an update.

Record why a training window was eligible when opened and keep it bound to its original actor, anchor, input snapshot and occurrence references through resolution. Recheck identity, timing, schema compatibility and required per-output evidence and coverage when resolving it; do not require an incidental collection trigger to recur. A target change alone does not invalidate a pending window whose identity and required coverage remain supported. Missing required evidence or coverage leaves the affected output unknown under the label rules above.

Start with nonoverlapping training windows per actor and at most one unresolved training window per tracked actor. Frequent inference may still serve a cached forecast, but repeated views of an occurrence must not multiply its learning weight. Multiple addon delivery routes for the same underlying observation count once; unresolved duplication cannot be treated as independent confirmation.

Batch small updates outside combat. Clip gradients, reject nonfinite updates, and retain a recoverable valid model. Keep an active evaluated model separate from the candidate being updated. Early behavior uses the explicit rules and simple empirical priors; randomly initialized neural outputs have no consumer authority.

Weights and compact training state may persist between sessions, keyed by ruleset, feature schema and interpretation, label definition and horizon, collection policy, and model version. Retained examples preserve the versions under which their inputs and labels were interpreted. Material compatibility changes require an explicit migration or invalidation and rebuild of the affected adaptation; old records must not silently acquire new meanings. Actor identity and unrelated raw combat histories do not need permanent storage for the first version.

## Runtime and integration

Implement the learner as one optional shared Lua component with thin adapters. Existing addons continue to function when that component is absent, disabled, stale, or unable to provide a supported prediction.

Start with the player, target, focus, and directly relevant relationships. Expose a bounded projection from existing state rather than introducing a second broad scanner.

Initial resource caps for the prototype are **16 actor records, 128 occurrence records, and 256 training examples**. These are adjustable engineering limits, not measured memory estimates. When a cap forces eviction, preserve required authoritative state in its owning addon and represent any lost learner context as unknown.

Use event coalescing, cached feature vectors, reusable buffers, and a bounded work queue. Enforce a per-update work allowance and measure processing time on the actual client. A full training pass never runs inside a combat event handler.

The first rollout records forecasts and outcomes without altering normal presentation. After it demonstrates value, enable one narrow consumer behavior at a time. Required observation and revision paths remain independent of learned attention and forecast usability. A low forecast, withheld output, or fallback must not block contradictory evidence, unfamiliar effects, or a correction to an existing occurrence.

For UI, keep established colours and layout exact. Its first contribution is meaningful context. Any later use of forecasts for emphasis or update scheduling is a separate consumer decision with its own measurable benefit. For Portraits, established aura priority and native rendering remain authoritative. For CC, forecasts remain distinguishable from observed applications and owned DR state.

## How the model earns its place

Evaluate the same eligible prediction windows with four approaches. Give every approach the same permitted semantic context, capability rules and missingness indicators; learned estimators use the same eligible training outcomes:

1. The current explicit rules and history.

2. Simple per-context event frequencies or timing distributions.

3. A small regularized linear or logistic scorer using the neural candidate's feature vector.

4. The neural candidate.

Use saved predictions made before the outcomes and evaluate across later encounters or sessions. Keep examples from one occurrence together; overlapping windows must not inflate the effective sample count. A model trained and tested on the same encounter history does not establish useful anticipation. Development choices made after inspecting shadow results require evaluation on later held-out encounters; scoring before an update does not make a repeatedly tuned evaluation set independent.

Report prediction loss, calibration where supported, event-family precision and recall at the selected operating point, actual lead time before the event, and the fraction of opportunities that were observable enough to evaluate. Report sparse families and censored windows separately.

Use bounded aggregate counts for received observations, eligible windows, resolved labels and examples used in updates by output family, and for delivered forecasts, changed decisions and evaluable outcomes by consumer. Count reasons for withholding or unresolved outcomes and keep stage denominators distinct. An unexercised path leaves model or consumer performance untested; delivery or a changed decision alone does not establish benefit.

Then measure consumer value. A lower prediction loss is insufficient if the enabled behavior adds distracting changes, delays a required update, or consumes more runtime than its benefit justifies.

For each comparator, report paired improvements, regressions and ties on the same eligible cases, grouped by event family, context and consumer. For later candidates, also compare against the last accepted compatible checkpoint on bounded replay of still-valid earlier context families alongside newer windows. Reused regression cases do not count as fresh held-out evidence. Judge forecasts by the declared prediction loss and enabled behavior by its frozen consumer metric. Keep protected invariant failures separate from predictive tradeoffs; equal aggregate scores do not imply preservation of previously successful cases.

Acceptance requires:

- A repeatable improvement over the strongest simple baseline on the declared task.

- Adequate label coverage for each enabled output and explicit withholding elsewhere.

- Correct behavior under duplicate observations, target changes, first sightings, and late corrections. After a wrong forecast, accept the unexpected observation and invalidate or revise the affected forecast; after correcting one occurrence, track a genuinely fresh subsequent occurrence independently.

- Stable outputs when only the colour palette changes while semantic identity stays fixed. Permitted adapter representations declared semantically equivalent must yield the same canonical features and numerical forecasts under frozen model parameters. Equivalence preserves actor and occurrence identity, event time, meaningful event order, relevant context, missingness, coverage and feature meanings.

- Preserved distinctions between histories that look the same now but imply different later effects. Paired replay cases cover an existing occurrence versus a fresh application, complete absence versus an observation gap, source versus recipient identity, and capability versus supported readiness. Preserve distinguishing evidence where available; otherwise require the appropriate unknown, estimate or withholding instead of an exact state claim. Expected treatments come from independently specified event histories and rules. Different future outcomes for identical predictive inputs may reflect uncertainty; they do not alone justify new features.

- Bounded state and acceptable processing cost on the player's client.

Before any forecast affects the live interface, freeze the evaluation window, relevant consumer metric, minimum practical improvement, protected replay cases, fallback conditions, per-consumer latency allowances, and the total runtime allowance for the shared learner and its adapters. Choose them from the profiling pass and intended use before evaluating the candidate's held-out results. Protected cases cover supported authoritative observations, occurrence identity and revision, incomplete coverage, and repeated use after correction. Run them through the actual consumer and fallback paths, checking the expected state before and after correction and verifying that the next relevant consumer read or decision uses the revised state. Include a replay control in which eligible corrective evidence arrives on time and is applied to the record, but propagation to the affected consumer is deliberately delayed beyond that consumer’s declared allowance. Preserve the valid correction and require the timeliness check to fail. For cache, event-coalescing, or adapter replacements, replay a bounded continuation containing a supported contradictory observation or occurrence correction. Feed events through the changed observation path and verify that required evidence retains its identity, meaning, coverage, and ability to revise the affected record, even when ordinary outputs otherwise agree. Promotion requires the predictive benefit and every protected invariant to pass within the declared allowances; report individual failures even when aggregate performance improves.

In shadow replay, hold the observations, anchored windows, initial encounter and consumer state, rules, feature extraction, adapters, consumer settings and label masks fixed, with learning disabled. Compare compatible parameter checkpoints of the same model before and after training, and restore each checkpoint in a fresh runtime. Numerical forecasts and outcome scores must match the corresponding replay within declared tolerances; discrete consumer decisions and protected state transitions must match exactly. Any improvement attributed to learning must follow the parameter change.

Use a separate bounded adaptation replay with a declared context change that makes a previously useful learned forecast association misleading. Let the candidate follow its normal update path, scoring each forecast before its outcome is used for learning. Track forecast loss and recovery over subsequent eligible observations and updates, while preserving valid earlier labels, feature and label meanings, and verified capability rules.

If the neural candidate does not outperform simpler estimators, keep the useful shared context and the better estimator. Additional model capacity requires a demonstrated remaining error.

## The Revisics connection

Revisics studies how transformations change the transformations that remain possible afterward. Its formal primitives require an explicit account of state, reachability, constraints, and the future operations a compressed representation must preserve. [Field definition](https://github.com/bjoern-janson/revisics/blob/f5874063b06997f49f3ee80d291de879c8d27a7f/foundations/FIELD_DEFINITION.md) · [Formal primitives](https://github.com/bjoern-janson/revisics/blob/f5874063b06997f49f3ee80d291de879c8d27a7f/foundations/FORMAL_PRIMITIVES_V0.md)

The application here has two distinct objects.

**The encounter changes.** A cast, effect, expiration, or resource expenditure can alter later feasible actions and outcomes under a declared ruleset and horizon.

**The learner's knowledge changes.** An observation, corrected timestamp, or revised hypothesis changes its estimate of those possibilities. Compressing history also changes which later distinctions it can reconstruct.

The design should preserve the distinctions needed for the chosen forecasts and revisions. DR history can matter after an aura disappears. Occurrence identity can matter after a timer is corrected. An uncertain optional capability can matter after several encounters without observing it.

This is a design application of the research framing. The repository's STRUCTURE-001 work remains prospective. Its B7 action-availability hypothesis should not be treated as an established result; changed CC effectiveness also does not automatically mean changed cast availability. [Candidate manifest](https://github.com/bjoern-janson/revisics/blob/f5874063b06997f49f3ee80d291de879c8d27a7f/experiments/STRUCTURE-001/CANDIDATE_SPECIFICATION_MANIFEST_V1.md) · [System construction status](https://github.com/bjoern-janson/revisics/blob/f5874063b06997f49f3ee80d291de879c8d27a7f/experiments/STRUCTURE-001/SYSTEM_CONSTRUCTION_MANIFEST_V1.md)

## First version

The first version should deliver one shared context model, one small anticipatory learner, and a way to inspect the evidence behind a forecast.

Build the context and occurrence contracts first. Add observation and forecast recording with the ordinary suite behavior intact. Establish which families have enough usable labels. Compare the small neural model with the simple baselines. Enable a consumer only after its prediction and practical benefit are demonstrated.

Timing calibration can be an auxiliary learning task using later verified timestamps. It should complement the anticipatory model rather than define the entire project.

The first decision after this draft is the consumer behavior worth enabling first. The recommended starting point is CC interpretation of a narrowly selected family, with UI supplying early identity context and Portraits supplying effects. Broad changes to display priorities and learned refresh scheduling can wait until the shared model has demonstrated its value.

## Source basis

The implementation observations in this draft refer to the supplied **bjarki-addons-foundation-v4-install(1).zip** snapshot:

- **bjarkiUI:** version 0.2.235-native-horizontal-party-test; identity, class, ownership, and opaque-rendering distinctions in `bjarkiUI.lua`.

- **bjarkiPortraits:** version 0.1.138-foundation-test; form-state inference in `AuraEngine.lua`, aura publishing in `EvidencePublisher.lua`, and explicit display categories in `Spells.lua` and `Priority.lua`.

- **bjarkiCC:** version 0.4.17.20-rg-evidence-chronology-test; bridge contract in `SharedEvidence.lua`, timing and occurrence reconciliation in `CooldownEvidence.lua` and `Model.lua`, and bounded explanation records in `Claims.lua`.

The linked Revisics sources are pinned to the revision inspected for this draft. MATRIX supplies a second design motivation: truth-preserving refinement of a candidate set can still lose executable correction opportunities, and available policies do not by themselves establish informed selection. [Finite feedback result](https://github.com/bjoern-janson/matrix/blob/5bca7ec6508e9d7ca1008ba745748281139fcfac/experiments/a2_v0/analysis/POST_EXECUTION_STRUCTURE_V0.md#L372-L448) · [Availability and selection boundary](https://github.com/bjoern-janson/matrix/blob/5bca7ec6508e9d7ca1008ba745748281139fcfac/formalization/GL_MATRIX_TRANSLATION_V0.md#L246-L287)

Interface Theory supplies a target-relative test: if permitted inputs cannot distinguish two admissible situations whose target differs, exact recovery is unavailable under that interface. Useful probabilistic forecasting may still be possible. The per-output contracts and paired cases above apply that distinction to the suite. [Factorization criterion](https://github.com/bjoern-janson/interface-theory/blob/61bef6c4eb9ee46cc38ac85a2f91874f9f8642a5/theorems/FACTORIZATION_CRITERION.md#L39-L235) · [Canonical record](https://github.com/bjoern-janson/interface-theory/blob/61bef6c4eb9ee46cc38ac85a2f91874f9f8642a5/docs/CANONICAL_RECORD.md)

Cerebro motivates separating a signal's provenance and meaning from the effects it may justify, retaining interpretation history through corrections, and recording consequential collection policies. [Warrant and effect separation](https://github.com/bjoern-janson/cerebro/blob/7c63d0f9024ee04d2ae84d979cc323b0ba37b613/program/network_architecture/WARRANT_EFFECT_SEPARABILITY_V0.1.md) · [Historical meaning and collection policy](https://github.com/bjoern-janson/cerebro/blob/7c63d0f9024ee04d2ae84d979cc323b0ba37b613/CEREBRO_CONSTITUTION_V0.1.md)

ARC Mk II supplies a finite example of terminal feedback changing a serialized linear query selector and improving held-out repairs. Its engineered features and replay implementation motivate the comparator and saved-state checks above. [Selector](https://github.com/bjoern-janson/arc-reactor-mk-ii/blob/731b10d709022151e524a64469b9088b14e6e93a/src/arc_mkii/selector.py) · [V2 result](https://github.com/bjoern-janson/arc-reactor-mk-ii/blob/731b10d709022151e524a64469b9088b14e6e93a/experiments/v2/g4-primary/PRIMARY_RESULT.json) · [Artifact replay](https://github.com/bjoern-janson/arc-reactor-mk-ii/blob/731b10d709022151e524a64469b9088b14e6e93a/src/arc_mkii/v2_g4_execution.py)

Revisable Computational Topology (RCT) documents an evidence handoff repair and a later restart failure when initializing a new connection. These motivate continuity of pending evidence, pipeline coverage and checks on restored training. [Handoff repair](https://github.com/bjoern-janson/revisable-computational-topology/blob/4bc8f91293cca0cfe3ece550601ba287482cebe2/docs/results/2026-09-10-bob-mk-ii-probe-warrant-repair-replay.md) · [Restart failure](https://github.com/bjoern-janson/revisable-computational-topology/blob/bea5c3d88e1ce423b4dfbc8f3e8cd76b855d763b/docs/results/2026-09-11-bob-mk-ii-lifetime-002-incomplete.md)

Intervention Response documents loss of previously practiced pair performance during later singleton training in a finite transformer task. Its checkpoint comparisons and shifted-input probes motivate the retention and equivalent-representation checks above. [Executed results](https://github.com/bjoern-janson/intervention-response/actions/runs/34538200968/artifacts/10176359339) · [Probe definitions](https://github.com/bjoern-janson/intervention-response/blob/f74b73f77d37cd49ac71b6bf1c2d6f5a66ed74e1/v0_3_checkpoint_localization.py)

Acquired Adaptive Advantage (AAA) distinguishes improved future learning from recovery when an acquired strategy becomes misleading. Its scripted reference controls motivate the adaptation replay above. [Concept and recovery](https://github.com/bjoern-janson/aaa/blob/24dfec7e37cea19d979a1f7221409e6be9b753b1/formalization/AAA_CONCEPT_V0.md) · [Reference controls](https://github.com/bjoern-janson/aaa/blob/24dfec7e37cea19d979a1f7221409e6be9b753b1/src/aaa_v0/agents.py)

Standing’s PEE-0 specification constructs two finite examples: a reward-improving intervention removes access to model-discriminating observations, and two processes equal under a restricted trajectory projection differ in access to those observations. These examples motivate the replay case for observation-path replacements above. [Frozen specification](https://github.com/bjoern-janson/standing/blob/f4c98aecbcf7367e12ff4e011b66b068d952bffb/epistemics/PEE-0_preregistration_v0.2.md)

Adaptive Leverage’s finite V2-0 result separates retained corrective distinctions, recovery through later evidence, and downstream write access. The replay’s abstract write predicate motivates verifying the actual corrected state and subsequent consumer use above. [Finite result](https://github.com/bjoern-janson/adaptive-leverage/blob/2d68c20301a7765a8a6e17b37f9c40bb878db29b/scientific_runs/ALCF-V2-0-001/SCIENTIFIC_RESULT.md) · [Replay implementation](https://github.com/bjoern-janson/adaptive-leverage/blob/2d68c20301a7765a8a6e17b37f9c40bb878db29b/src/adaptive_leverage/v2/replay.py)

Creative Corrigibility’s finite calibration apparatus separates actual correction from timely completion. Its delayed control reduces authority after commitment and beyond the declared horizon, motivating the replay control for delayed propagation above. [Calibration cases](https://github.com/bjoern-janson/creative-corrigibility/blob/9191773743eb4eea7c45bb0f3d1fe51fb0020cbb/src/creative_corrigibility/calibration.py) · [Trace measurement](https://github.com/bjoern-janson/creative-corrigibility/blob/9191773743eb4eea7c45bb0f3d1fe51fb0020cbb/src/creative_corrigibility/measurement.py)

The interface, forecast and acceptance contracts above apply these distinctions to bjarkiLearn. The finite research audits establish results for their declared systems; the suite's behavior must pass its own evaluation. Proposed architecture, capacities, horizon, and evaluation procedures remain design choices.
