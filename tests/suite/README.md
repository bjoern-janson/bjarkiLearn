# Suite bridge contract tests

Run from the bjarkiLearn repository root with the frozen Portraits and CC source checkouts:

```sh
lua5.1 tests/suite/test_bridge.lua ../bjarkiPortraits ../bjarkiCC
lua5.4 tests/suite/test_bridge.lua ../bjarkiPortraits ../bjarkiCC
lua5.1 tests/suite/test_mutation.lua ../bjarkiPortraits ../bjarkiCC
lua5.4 tests/suite/test_mutation.lua ../bjarkiPortraits ../bjarkiCC
```

The normal harness reports **20 cases** per interpreter. The separate negative control must report that dropping the publisher's native application identity breaks the Learn consumer assertion. It temporarily changes the actual `EvidencePublisher.lua` source in memory while loading it, runs the same suite, and restores the loader. It does not edit the checked-out addon files or create a production test entry point. A passing unmutated suite and a detected mutation are both required evidence.

`support.lua` models only client APIs and frame methods. Every addon module loads from its real `.toc`, in its shipped module order. The first two scenarios start with no consumer evidence, dispatch a real Portraits `UNIT_AURA` event for a derived unit (which CC's general event path does not consume), and assert both CC cooldown rows and Learn occurrences/public context. This establishes publisher-to-consumer causality. No normal positive test injects a bus record directly; the direct `Publish` call is a malformed negative-schema rejection check.

Coverage includes both bus creators; target-of-target and focus-of-target snapshots; added versus first-sighting metadata; repeated observations; readable timing refinement/correction; distinct applications; queued identity rebinding; actual world-event handlers in either Portraits/CC registration order; Learn disable/re-enable via its slash handler; optional addon absence; bounded replay; and positive-only eligibility and omission semantics. Bus callback errors and Learn faults fail the checks.

The supported addon load-order cases put Learn after its optional dependencies and allow either Portraits or CC to create the identical bus first. Learn-first and publication-before-subscription are explicitly resilience probes, not claims about the client's dependency resolver. World recovery also exercises CC's current native reread: CC deliberately does not resurrect an absent aura from bus history. Learn deliberately replays recent historical positives, preserving their source observation time; an expired witness does not become confirmed presence or absence. These are different consumer contracts.

The authoritative external revisions and frozen install hashes are in [candidate.json](candidate.json). Before running against a candidate, check all four source trees:

```sh
python3 tests/suite/verify_candidate.py --portraits ../bjarkiPortraits --cc ../bjarkiCC --ui ../bjarkiUI --learn .
```

When intentionally changing a frozen addon payload, review and refresh the manifest's immutable revision, version, archive provenance and file hashes together, then rerun verification and these tests. Tests and launch documents are repository material, separate from the frozen install payload.

This harness does not validate portrait rendering, secure native aura widgets, taint/secret enforcement, native event availability/cadence, client performance, stance perspective, decimal rendering, or DR mechanics. Native portrait frames are absent; CC frame methods are ordinary fixtures. The `unpack` compatibility alias models the global supplied by WoW when running the harness on Lua 5.4. Protected-value sentinels model fail-closed decisions only. Live validation remains pending.
