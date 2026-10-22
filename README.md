# bjarkiLearn

A proposed shared Lua learner for the Bjarki World of Warcraft addon suite. It combines readable encounter context with a small predictive model so the suite can anticipate relevant events and learn from later observations.

**Status: design draft 0.11 · 22 October 2026.** Lua implementation and in-client validation are pending.

**[Read the complete design](DESIGN.md)** for the observation, forecast, correction, training, runtime, and acceptance contracts, together with the pinned research sources.

## Purpose

Use the meaning behind the suite's existing class, ownership, form, aura, and control rules to establish what may be possible before an event occurs. Learn contextual forecasts from eligible observations while keeping confirmed events, inferred state, and predictions distinguishable.

A small neural candidate must demonstrate value against explicit rules, empirical estimates, and a linear or logistic baseline. Each enabled consumer must show a practical benefit within its runtime allowance.

## Roles in the suite

| Component | Role |
| --- | --- |
| bjarkiUI | Supplies readable actor identity, class, ownership, and relationships. |
| bjarkiPortraits | Supplies readable effects and supported state witnesses. |
| bjarkiCC | Supplies occurrence history, recipient DR state, timing evidence, and corrections. |
| bjarkiLearn | Maintains shared context and hypotheses, learns forecasts, and serves narrow consumer projections. |

The owning addons retain their authoritative state and presentation rules. The learner is an optional shared component with thin adapters.

## Design commitments

- Keep capability, availability, and recipient effect separate.
- Preserve occurrence identity and provenance through corrections, including revisions to training examples.
- Ground labels in qualifying observations; coverage gaps remain unknown.
- Keep evidence intake and correction available when forecasts are low, withheld, or using fallback.
- Bound records, training history, and work per update; profile on the actual client.
- Verify corrected state, subsequent consumer use, and timely propagation before enabling behavior.

## First implementation sequence

1. Build the context and occurrence contracts.
2. Record observations and forecasts in shadow mode.
3. Establish which output families have usable labels.
4. Compare the candidate models on held-out encounters and bounded replay.
5. Enable one narrow consumer behavior after it meets the declared prediction, practical-benefit, and preservation criteria.

The recommended first consumer is a narrowly selected CC interpretation, with UI supplying identity context and Portraits supplying effects. The complete draft records the proposed capacities, evaluation procedures, and remaining design choices.
