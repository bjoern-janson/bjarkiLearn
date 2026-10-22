return function(ns, T)
    local W = WoW
    local function recordingCore()
        local core = { contexts = {}, casts = {}, auras = {}, gaps = {}, coverages = {}, resets = {} }
        function core:Context(record) self.contexts[#self.contexts + 1] = record end
        function core:Cast(record) self.casts[#self.casts + 1] = record end
        function core:Aura(record) self.auras[#self.auras + 1] = record end
        function core:Gap(reason, actor) self.gaps[#self.gaps + 1] = { reason = reason, actor = actor } end
        function core:SetCoverage(value) self.coverages[#self.coverages + 1] = value end
        function core:ResetSession(now) self.resets[#self.resets + 1] = now end
        return core
    end
    local function setup()
        W.Reset(); BjarkiEvidenceV1 = nil
        local core = recordingCore()
        T.ok(ns.Adapter and ns.Adapter.New, 'native adapter exists')
        return ns.Adapter.New(core), core
    end
    local function latestContext(core, actor)
        for i = #core.contexts, 1, -1 do
            if core.contexts[i].actor == actor then return core.contexts[i] end
        end
    end

    T.case('normalizes semantic class, role, health and supported form without colors', function()
        local adapter, core = setup()
        adapter:SetRegistered(true); adapter:Tick(0)
        local self = latestContext(core, 'Player-1-self')
        local enemy = latestContext(core, 'Player-1-enemy')
        T.eq(self.class, 'PRIEST'); T.eq(self.role, 'self'); T.near(self.health, .8)
        T.eq(self.regime, 'player'); T.eq(enemy.role, 'hostile'); T.eq(enemy.form, 'cat')
        T.eq(enemy.regime, 'other'); T.eq(core.coverages[#core.coverages], true)
        W.units.target.powerToken = 'MANA'; adapter:Tick(.25)
        T.eq(latestContext(core, 'Player-1-enemy').form, nil, 'mana does not identify a form')
    end)

    T.case('aliases preserve actor and occurrence identity without assigning recipient effects', function()
        local adapter, core = setup()
        W.units.focus = W.units.target
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'target', 'Cast-1', 8122)
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'focus', 'Cast-1', 8122)
        T.eq(#core.casts, 2, 'core receives identities and owns duplicate reconciliation')
        T.eq(core.casts[1].actor, core.casts[2].actor)
        T.eq(core.casts[1].id, core.casts[2].id)
        T.eq(core.casts[1].family, 1); T.eq(core.casts[1].source, 'native-cast')
        T.eq(core.casts[1].at, 0); T.eq(adapter:Resolve('focus'), 'Player-1-enemy')
    end)

    T.case('rebinding censors the old actor and attributes the next cast to the new GUID', function()
        local adapter, core = setup(); adapter:Tick(0)
        W.units.target.guid = 'Player-1-replacement'; W.clock = .1
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'target', 'Cast-new', 8122)
        T.eq(core.casts[1].actor, 'Player-1-replacement')
        local sawGap, oldUnbound = false, false
        for _, gap in ipairs(core.gaps) do if gap.actor == 'Player-1-enemy' then sawGap = true end end
        for _, context in ipairs(core.contexts) do
            if context.actor == 'Player-1-enemy' and context.bound == false then oldUnbound = true end
        end
        T.ok(sawGap); T.ok(oldUnbound)
    end)

    T.case('secret identity and event fields never become absence evidence', function()
        local adapter, core = setup(); adapter:SetRegistered(true); adapter:Tick(0)
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', W.secret, 8122)
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-secret-spell', W.secret)
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', W.secret, 'Cast-secret-unit', 8122)
        T.eq(#core.casts, 0); T.ok(#core.gaps >= 3)
        W.units.player.guid = W.secret; adapter:Tick(.25)
        T.eq(core.coverages[#core.coverages], false)
        T.eq(adapter:Resolve('player'), nil)
    end)

    T.case('unknown spell IDs and untracked readable units do not manufacture labels', function()
        local adapter, core = setup()
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-unknown', 9999999)
        adapter:OnEvent('UNIT_SPELLCAST_SUCCEEDED', 'nameplate1', 'Cast-nameplate', 8122)
        T.eq(#core.casts, 0); T.eq(#core.gaps, 0)
    end)

    T.case('failed registration and heartbeat stalls constrain negative coverage', function()
        local adapter, core = setup()
        adapter:SetRegistered(false); adapter:Tick(0)
        T.eq(core.coverages[#core.coverages], false)
        adapter:SetRegistered(true); adapter:Tick(.25)
        T.eq(core.coverages[#core.coverages], true)
        adapter:Tick(1)
        local saw = false
        for _, gap in ipairs(core.gaps) do if gap.reason == 'scheduler-gap' then saw = true end end
        T.ok(saw)
    end)

    T.case('refresh work is capped at three unit bindings and a quarter second cadence', function()
        local adapter, core = setup(); adapter:Tick(0)
        local count = #core.contexts
        for i = 1, 24 do adapter:Tick(i / 100) end
        T.eq(#core.contexts, count)
        adapter:Tick(.25); T.ok(#core.contexts <= count + 3)
    end)

    T.case('positive aura replay stays context and preserves first-sighting semantics', function()
        local adapter, core = setup(); local subscribed, stopped
        BjarkiEvidenceV1 = {
            protocol = 'bjarki-positive-aura-v1', schema = 1,
            Subscribe = function(_, key, callback, now)
                subscribed = key
                callback({ source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
                    recipientGUID = 'Player-1-enemy', unit = 'target', spellId = 22812,
                    auraInstanceID = 17, observedAt = now, expirationTime = 12, duration = 12,
                    newApplication = false })
                return true
            end,
            Unsubscribe = function(_, key) stopped = key end,
        }
        T.eq(adapter:ConnectBus(0), true)
        T.eq(subscribed, 'bjarkiLearn.aura-evidence'); T.eq(#core.auras, 1)
        T.eq(core.auras[1].newApplication, false); T.eq(core.auras[1].recipient, 'Player-1-enemy')
        T.eq(#core.casts, 0); T.eq(#core.coverages, 0)
        adapter:Stop(); T.eq(stopped, subscribed)
    end)

    T.case('incompatible bus and malformed positives are rejected without mutation', function()
        local adapter, core = setup()
        BjarkiEvidenceV1 = { protocol = 'future-protocol', schema = 2 }
        T.eq(adapter:ConnectBus(0), false)
        local callback
        BjarkiEvidenceV1 = { protocol = 'bjarki-positive-aura-v1', schema = 1,
            Subscribe = function(_, _, fn) callback = fn; return true end,
            Unsubscribe = function() end }
        T.eq(adapter:ConnectBus(0), true)
        callback(W.secret)
        callback({ source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
            recipientGUID = W.secret, spellId = 22812, observedAt = 0, auraInstanceID = 3 })
        T.eq(#core.auras, 0)
    end)

    T.case('unsupported or unidentified auras do not consume occurrence capacity', function()
        local adapter, core = setup()
        local raw = { source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
            recipientGUID = 'Player-1-enemy', unit = 'target', spellId = 1044,
            auraInstanceID = 19, observedAt = 0, newApplication = true }
        adapter:OnAura(raw)
        raw.spellId, raw.auraInstanceID = 22812, nil; adapter:OnAura(raw)
        T.eq(#core.auras, 0, 'no anonymous ID or unrelated aura is promoted to learner evidence')
    end)

    T.case('world entry resets transient continuity without erasing a retained corpus', function()
        local adapter, core = setup(); adapter:Tick(0)
        W.clock = 10; adapter:OnEvent('PLAYER_ENTERING_WORLD')
        T.eq(#core.resets, 1); T.eq(core.resets[1], 10)
        T.eq(adapter:Resolve('player'), 'Player-1-self')
    end)

    T.case('world entry restores recent bridge witnesses without replaying casts or stale positives', function()
        W.Reset(); W.clock = 100
        local recent = {
            { source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
                recipientGUID = 'Player-1-enemy', unit = 'target', spellId = 22812,
                auraInstanceID = 33, observedAt = 99, expirationTime = 111, duration = 12,
                newApplication = false },
            { source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
                recipientGUID = 'Player-1-enemy', unit = 'target', spellId = 5277,
                auraInstanceID = 34, observedAt = 90, expirationTime = 120, duration = 30,
                newApplication = false },
        }
        -- The existing v1 bus makes identical subscriptions idempotent and
        -- snapshots only the last eight seconds for a new subscription.
        local listeners = {}
        BjarkiEvidenceV1 = { protocol = 'bjarki-positive-aura-v1', schema = 1,
            Subscribe = function(_, key, callback, now)
                if listeners[key] == callback then return true end
                listeners[key] = callback
                for _, record in ipairs(recent) do
                    if record.observedAt <= now and now - record.observedAt <= 8 then callback(record) end
                end
                return true
            end,
            Unsubscribe = function(_, key) listeners[key] = nil; return true end,
        }
        local core = ns.Core.New(); local adapter = ns.Adapter.New(core)
        adapter:Tick(100); T.eq(adapter:ConnectBus(100), true)
        T.eq(core:GetContext('Player-1-enemy', 100).defensiveWitness.expires, 111)
        W.clock = 100.25; adapter:OnEvent('PLAYER_ENTERING_WORLD')
        local context = core:GetContext('Player-1-enemy', 100.25)
        T.ok(context.defensiveWitness, 'recent positive context survives a world-entry reset through bounded replay')
        T.eq(context.defensiveWitness.expires, 111)
        T.eq(core:Status().occurrences, 1, 'old replay candidates remain excluded')
        T.eq(core:Status().casts or 0, 0)
        T.eq(core:Status().examples, 0)
        adapter:Stop(); BjarkiEvidenceV1 = nil
    end)

    T.case('main lifecycle gates coverage, defers work, and exposes copied shadow diagnostics', function()
        W.Reset(); BjarkiEvidenceV1, BjarkiLearn, bjarkiLearnDB = nil, nil, nil
        T.ok(ns.Main and ns.Main.New, 'main lifecycle exists')
        local core, original = recordingCore(), ns.Core
        core.ticks = {}
        function core:Tick(now, combat) self.ticks[#self.ticks + 1] = { now = now, combat = combat } end
        function core:Status() return { examples = 3, test = { value = 1 } } end
        function core:GetContext(actor) return { actor = actor, class = 'PRIEST' } end
        function core:Forecast(actor) return { actor = actor, mode = 'shadow' } end
        function core:Export() return { saved = true } end
        function core:Restore(saved) self.restored = saved end
        ns.Core = { New = function() return core end }
        local runtime = ns.Main.New()
        runtime.frame:Fire('ADDON_LOADED', 'bjarkiLearn')
        ns.Core = original
        T.eq(runtime.initialized, true); T.eq(runtime.enabled, true)
        T.eq(#core.ticks, 0, 'event handlers do not train or resolve windows')
        runtime.frame:Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-main', 8122)
        T.eq(#core.casts, 1); T.eq(#core.ticks, 0)
        W.combat = true; W.clock = .1; runtime.frame:Update(.1)
        T.eq(core.ticks[1].combat, true)
        W.combat = false; W.clock = .2; runtime.frame:Update(.1)
        T.eq(core.ticks[2].combat, false)
        T.eq(BjarkiLearn.protocol, 'bjarki-learn-v1')
        local status = BjarkiLearn:Status(); status.core.test.value = 99
        T.eq(BjarkiLearn:Status().core.test.value, 1)
        T.eq(BjarkiLearn:Forecast('player').mode, 'shadow')
        runtime:Command('disable'); T.eq(runtime.enabled, false)
        local count = #core.casts
        runtime.frame:Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-disabled', 8122)
        T.eq(#core.casts, count); T.eq(BjarkiLearn:Forecast('player'), nil)
        runtime.frame:Fire('PLAYER_LOGOUT')
        T.eq(bjarkiLearnDB.enabled, false); T.eq(bjarkiLearnDB.learning.saved, true)
    end)

    T.case('failed native registration and incompatible public globals fail closed', function()
        W.Reset(); BjarkiEvidenceV1, bjarkiLearnDB = nil, nil
        W.rejectedEvents.UNIT_SPELLCAST_SUCCEEDED = true
        local existing = { protocol = 'different-interface' }; BjarkiLearn = existing
        T.ok(ns.Main and ns.Main.New, 'main lifecycle exists')
        local core, original = recordingCore(), ns.Core
        function core:Restore() end
        function core:Export() return {} end
        function core:Status() return {} end
        ns.Core = { New = function() return core end }
        local runtime = ns.Main.New()
        runtime.frame:Fire('ADDON_LOADED', 'bjarkiLearn')
        ns.Core = original
        T.eq(BjarkiLearn, existing)
        T.eq(core.coverages[#core.coverages], false)
        T.eq(runtime:Status().castRegistered, false)
        runtime:Command('disable')
        BjarkiLearn = nil
    end)

    T.case('real core accepts a native aura identity and revises one positive witness', function()
        W.Reset(); BjarkiEvidenceV1 = nil
        local core = ns.Core.New(); local adapter = ns.Adapter.New(core)
        adapter:Tick(0)
        local raw = { source = 'bjarkiPortraits', kind = 'aura-positive', isHelpful = true,
            recipientGUID = 'Player-1-enemy', unit = 'target', spellId = 22812,
            auraInstanceID = 17, observedAt = 0, expirationTime = 12, duration = 12,
            newApplication = false }
        adapter:OnAura(raw)
        T.eq(core:Status().auraWitnesses, 1)
        T.eq(core:GetContext('Player-1-enemy', 0).defensiveWitness.expires, 12)
        raw.observedAt, raw.expirationTime = .1, 13; adapter:OnAura(raw)
        T.eq(core:Status().occurrences, 1); T.eq(core:Status().auraRevisions, 1)
        T.eq(core:GetContext('Player-1-enemy', .1).defensiveWitness.expires, 13)
        T.eq(core:Status().casts or 0, 0)
    end)

    T.case('losing an alias cannot censor a continuously observed player window', function()
        W.Reset(); BjarkiEvidenceV1 = nil
        W.combat = true; W.units.target = W.units.player
        local core = ns.Core.New(); local adapter = ns.Adapter.New(core)
        adapter:SetRegistered(true); adapter:Tick(0); core:Tick(0, true)
        W.units.target = nil; W.clock = .1
        adapter:OnEvent('PLAYER_TARGET_CHANGED')
        for i = 1, 9 do W.clock = i * .25; adapter:Tick(W.clock); core:Tick(W.clock, true) end
        T.eq(core.examples[1].regime, 'player')
        for i = 1, 6 do T.eq(core.examples[1].mask[i], true) end
    end)

    T.case('unknown combat state censors pending windows without opening or training', function()
        W.Reset(); BjarkiLearn, BjarkiEvidenceV1, bjarkiLearnDB = nil, nil, nil
        W.combat = true
        local runtime = ns.Main.New()
        runtime.frame:Fire('ADDON_LOADED', 'bjarkiLearn'); runtime.frame:Update(0)
        W.combat = nil
        for i = 1, 25 do W.clock = i * .1; runtime.frame:Update(.1) end
        local status = runtime:Status().core
        T.eq(status.pending, 0); T.eq(status.trainingSteps, 0)
        T.eq(status.families[1].negative, 0)
        T.ok((status.gapReasons['unreadable-combat'] or 0) > 0)
        runtime:Command('disable')
    end)

    T.case('real lifecycle collects native events before later out-of-combat learning', function()
        W.Reset(); BjarkiLearn, BjarkiEvidenceV1, bjarkiLearnDB = nil, nil, nil
        W.combat = true
        local runtime = ns.Main.New()
        runtime.frame:Fire('ADDON_LOADED', 'bjarkiLearn'); runtime.frame:Update(0)
        for i = 1, 25 do
            W.clock = i * .1
            if i == 10 then
                runtime.frame:Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-player-real', 8122)
                runtime.frame:Fire('UNIT_SPELLCAST_SUCCEEDED', 'target', 'Cast-enemy-real', 8122)
            end
            runtime.frame:Update(.1)
        end
        local before = runtime:Status().core
        T.eq(before.casts, 2); T.ok(before.examples >= 2)
        T.eq(before.trainingSteps, 0)
        T.eq(before.families[1].positive, 1); T.eq(before.families[1].otherPositive, 1)
        T.eq(before.families[2].negative, 1)
        W.combat = false; W.units.player.combat = false
        runtime.frame:Fire('PLAYER_REGEN_ENABLED')
        for i = 26, 80 do W.clock = i * .1; runtime.frame:Update(.1) end
        T.ok(runtime:Status().core.trainingSteps > 0)
        runtime:Command('status'); runtime:Command('inspect player')
        T.ok(#W.messages > 0)
        runtime:Command('reset'); T.eq(runtime:Status().core.examples, 0)
        runtime:Command('disable')
    end)
end
