# Long memory: 0.2.0 experimental contract

## What persists

The prior learner's 48-feature, six-family task is unchanged. It still trains
only on eligible local-player cast delivery windows, with explicit label masks.
Enemy negative labels remain unsupported. Every forecast stays shadow-only.

The new memory is **bounded evidence**, not an unbounded event log:

- Up to 256 recent examples, including revisable active-session records.
- Up to 128 deidentified, immutable rehearsal examples selected from examples
  *sealed at a prior session boundary* and later evicted from recent memory.
- Six independent positive-family reservoirs (16 samples each), and one
  background reservoir (32 samples). A row positive in multiple families
  enters the first positive family in the stable rule order.
- Reservoir randomness is an explicit, versioned Park–Miller integer state;
  counts and selected samples persist across reloads.
- The candidate trains on all archive rows plus the latest 128 eligible recent
  rows, never more than the existing 256-row/4-epoch budget.
- Only a completed serving model whose source corpus is current is eligible
  for checkpoint serialization. Its model state is an *optional cache*, not a
  replacement for the bounded evidence needed to retrain it.

The archive is intentionally representative **within each family stratum**,
not an unbiased sample of all gameplay. This can improve rare-family coverage,
but changes the training distribution. Frequency baselines and per-family
calibration must be evaluated on independent naturally occurring windows, not
on this stratified training distribution.

## Finality and correction

A source revision may revise an unsealed recent window and invalidate its
dependent serving model as before. The learner never copies such a window to
long-term memory at ordinary eviction; it records archiveSkippedUnsealed.

Session reset/reload seals recent examples, discards runtime actor/occurrence
identities and ends their correction scope. Only sealed examples can later
enter the archive. They contain only features, binary labels and masks: no
character name, GUID, cast identifier, outcome timing or raw aura record.
Corrections cannot be applied to those irreversible deidentified records.
This *matches the existing session boundary*, but does not establish that all
late evidence is impossible. If the underlying evidence contract ever gains
cross-session revision, the archive policy must change before adopting that
source. This implementation does not claim arbitrary retrospective correction.

Rehearsal selection occurs when the sealed recent example is evicted. Rows
from the current session that overflow the recent buffer are **not archived**.
That is deliberate conservatism, not perfect long-term coverage. First-session
examples therefore only enter the archive after they survive a session
boundary and are subsequently retired by newer examples. A single extremely
long session still has only recent 256-window memory until reset.

## Restore and trusted state

Persistent schema 2 includes compatible recent examples, seven dense archive
buckets, total seen counters, the RNG state, and a deterministic numeric
corpus signature. Archive validation is atomic; corrupt archive contents
reject the restore without replacing the running core. Older 0.1.x learning
does not silently acquire new semantics.

The optional full numeric checkpoint is validated by Network.Restore and
must match the rebuilt corpus signature. A corrupt or mismatched optional
checkpoint is rejected while the valid corpus is retained and replayed.
The signature is an accidental-corruption guard, **not cryptographic
authentication** or a proof that an arbitrary manually edited checkpoint was
trained on its claimed examples. Training history remains the authority.

Changes to sample feature meanings, source label coverage, class association
rules, bucket allocation, training schedule or checkpoint interpretation
require a new compatibility key. The public read-only protocol remains v1.

## Limitations

This is the *first phase* of continual learning. The long-term model gains
persistent exposure to selected earlier sessions, but still rebuilds from a
fixed seed on each dirty corpus. The cached checkpoint speeds restart; it does
not yet perform irreversible online weight consolidation. This is intentional:
retaining a bounded, reproducible correction path comes before introducing
harder-to-undo parameter accumulation.

Longer-term work, after actual Forever data establishes utility:
1. Measure sampled/training/recent denominators separately on live sessions.
2. Add a frozen held-out timeline that never influences reservoir selection.
3. Add narrow CC evidence with source-specific coverage and finality rules.
4. Promote a checkpoint only after a repeatable advantage over linear and
   frequency baselines, preserving the previous accepted fallback.
5. Investigate durable weight consolidation *only* if the bounded rehearsal
   bank demonstrably leaves useful learnable information behind.

## Verification

From the repository root:

    lua5.1 tests/long_memory.lua
    lua5.4 tests/long_memory.lua

CI also syntax-compiles all six Lua runtime files under both engines. These
are initial regressions for the long-memory change, not a rerun of the full
0.1.6 verification archive. In-client secret/taint behavior, actual delivery,
frame-time overhead, and predictive or consumer benefits still require
independent validation.
