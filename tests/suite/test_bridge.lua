-- Run from Learn root: lua5.1 tests/suite/test_bridge.lua PORTRAITS_PATH CC_PATH
local T=assert(loadfile('tests/suite/support.lua'))()
local eq,aura=T.equal,T.aura
local paths={bjarkiLearn='.',bjarkiPortraits=assert(arg[1],'Portraits source path required'),
    bjarkiCC=assert(arg[2],'CC source path required')}
local P,C,L='bjarkiPortraits','bjarkiCC','bjarkiLearn'
local G,OTHER='Player-1-Enemy','Player-1-Rebound'
local passed,failures=0,{}
local function test(name,body)
    local ok,why=pcall(body)
    if ok then passed=passed+1; print('PASS '..name)
    else failures[#failures+1]=name..': '..tostring(why); print('FAIL '..failures[#failures]) end
end
local function setup(order,unit)
    local h=T.new(paths,order or {P,C,L})
    h:bind(unit or 'targettarget',G)
    h:bind('target',G)
    h:fire('PLAYER_TARGET_CHANGED'); h:drain()
    return h
end
local function learnStatusText()
    local lines={}
    DEFAULT_CHAT_FRAME.AddMessage=function(_,line) lines[#lines+1]=line end
    SlashCmdList.BJARKILEARN('status')
    return table.concat(lines,'\n')
end
local function consumers(h,guid,id)
    local row=assert(h:row(guid),'CC cooldown follows Portraits publication')
    local occurrence=assert(h:occurrence(guid,id),'Learn aura follows Portraits publication')
    eq(occurrence.kind,'aura','Learn context evidence kind')
    eq(occurrence.source,'bjarkiPortraits','Learn evidence provenance')
    eq(h.addons[L].Runtime.core.stats.casts or 0,0,'aura cannot create Learn cast outcomes')
    h:healthy()
    return row,occurrence
end
for _,order in ipairs({{P,C,L},{C,P,L}}) do
    local label=order[1]..' creates bus (supported OptionalDeps order)'
    test(label,function()
        local h=setup(order)
        assert(h.addons[P].EvidenceBus==h.addons[C].EvidenceBus,'one actual shared bus')
        eq(BjarkiEvidenceV1.stats.published,0,'no fabricated publication in setup')
        eq(h:row(G),nil,'CC starts without evidence')
        eq(h:occurrence(G),nil,'Learn starts without evidence')
        h:added('targettarget',aura(21,98,12))
        local row=consumers(h,G)
        eq(row.started,98,'CC reads producer timing')
        local context=assert(BjarkiLearn:GetContext('target'),'bound Learn context')
        eq(context.defensiveWitness.spellID,22812,'public Learn defensive witness')
        eq(BjarkiEvidenceV1.stats.published,1,'derived added event publishes once before empty snapshot')
    end)
end
for _,unit in ipairs({'targettarget','focustarget'}) do
    test(unit..' snapshots refine without another application',function()
        local h=setup(nil,unit)
        h:snapshot(unit,aura())
        local first,occ=consumers(h,G)
        local claim=first.claimID
        assert(first.timingEstimated,'untimed first sighting estimated')
        eq(first.started,100,'snapshot starts estimated at observation')
        eq(BjarkiEvidenceV1.recent[1].newApplication,false,'snapshot is first sighting')
        h.clock=101; h:snapshot(unit,aura(21,98,12))
        local row,refined=consumers(h,G)
        eq(row.claimID,claim,'refinement conserves claim identity')
        eq(row.started,98,'exact time repairs estimate'); eq(row.timingEstimated,false,'exact timing')
        eq(refined.expires,110,'Learn receives refined expiry')
        h.clock=102; h:snapshot(unit,aura(21,98,16))
        local corrected=consumers(h,G)
        eq(corrected.claimID,claim,'duration correction conserves claim')
        eq(h:occurrence(G).expires,114,'Learn accepts expiry correction')
        h.clock=103; h:snapshot(unit,aura(21,98,16))
        eq(h:row(G).claimID,claim,'repeat snapshot cannot create another CC use')
        eq(#h.addons[L].Runtime.core.occurrenceOrder,1,'repeat snapshot merges Learn occurrence')
        assert(h:occurrence(G).revision>occ.revision,'later observation revises one Learn witness')
        eq(h.addons[C].CooldownEvidence.stats.helpfulAccepted,1,'one accepted activation')
        h:healthy()
    end)
    test(unit..' added event precedes snapshot and later new application',function()
        local h=setup(nil,unit)
        local first=aura(21,98,12); h.auras[unit]={[22812]=first}
        h:added(unit,first)
        local row=consumers(h,G); local claim=row.claimID
        eq(#BjarkiEvidenceV1.recent,2,'added plus deferred snapshot both publish')
        eq(BjarkiEvidenceV1.recent[1].newApplication,true,'added event application flag')
        eq(BjarkiEvidenceV1.recent[2].newApplication,false,'following snapshot does not claim application')
        eq(h:row(G).claimID,claim,'two producer records are one CC application')
        eq(#h.addons[L].Runtime.core.occurrenceOrder,1,'same native aura identity merges in Learn')
        h.clock=165; h.auras[unit]={[22812]=aura(22,165,12)}
        h:added(unit,h.auras[unit][22812])
        local second=consumers(h,G,22)
        eq(second.started,165,'independent new application has new start')
        assert(second.claimID~=claim,'new application receives new claim')
        eq(#h.addons[L].Runtime.core.occurrenceOrder,2,'distinct native identity retained separately')
    end)
end
for _,order in ipairs({{P,C,L},{C,P,L}}) do
    test(order[1]..' world handler order recovers current derived evidence',function()
        local h=setup(order)
        h:snapshot('targettarget',aura(21,98,12))
        local session=h.addons[L].Runtime.core.session
        h.clock=101; h:fire('PLAYER_ENTERING_WORLD'); h:drain()
        local row=consumers(h,G)
        eq(row.started,98,'current world observation survives reset ordering')
        eq(#h.addons[L].Runtime.core.occurrenceOrder,1,'Learn replays/reconciles once after session reset')
        eq(h.addons[L].Runtime.core.session,session+1,'Learn actual world event resets session')
        h:healthy()
    end)
end
test('world reset does not resurrect absent CC evidence; Learn bounded replay remains historical positive',function()
    local h=setup(); h:snapshot('targettarget',aura(21,98,12))
    h.clock=101; h.auras.targettarget={}; h:fire('PLAYER_ENTERING_WORLD'); h:drain()
    eq(h:row(G),nil,'CC requires current world evidence, not bus history')
    assert(h:occurrence(G),'Learn intentionally replays recent positives after reset')
    eq(h:occurrence(G).at,100,'replay keeps original observation clock')
    h.clock=120; h:fire('PLAYER_ENTERING_WORLD'); h:drain()
    eq(h:occurrence(G),nil,'Learn does not replay outside eight-second window')
    h:healthy()
end)
test('queued derived snapshot reads rebound identity and Learn binding changes',function()
    local h=setup(); h:snapshot('targettarget',aura(21,98,12))
    h.clock=101; h:fire('UNIT_AURA','targettarget',{updatedAuraInstanceIDs={21}})
    h:bind('targettarget',OTHER); h:bind('target',OTHER)
    h.auras.targettarget={[22812]=aura(22,100,12)}
    h:fire('PLAYER_TARGET_CHANGED'); h:drain()
    consumers(h,OTHER,22)
    eq(h:occurrence(G).at,100,'queued record does not overwrite old recipient')
    local context=assert(BjarkiLearn:GetContext('target'))
    eq(context.defensiveWitness.at,101,'current binding sees new recipient witness')
    eq(h.addons[L].Runtime.adapter.bindings.target,OTHER,'native binding refreshed')
end)
for _,unit in ipairs({'target','focus'}) do
    local event=unit=='target' and 'PLAYER_TARGET_CHANGED' or 'PLAYER_FOCUS_CHANGED'
    test('public '..unit..' queries before Learn handles a rebind',function()
        local h=T.new(paths,{P})
        local observer=CreateFrame('Frame')
        observer:RegisterEvent(event)
        local checking=false
        observer:SetScript('OnEvent',function()
            if not checking then return end
            local before=BjarkiLearn:Status().adapter
            for _,key in ipairs({unit,G,OTHER}) do
                eq(BjarkiLearn:GetContext(key),nil,'no context before binding refresh: '..key)
                eq(BjarkiLearn:Forecast(key),nil,'no forecast before binding refresh: '..key)
            end
            local after=BjarkiLearn:Status().adapter
            eq(after.contexts,before.contexts,'read-only query cannot bind the new actor')
            eq(after.gaps,before.gaps,'read-only query cannot record a coverage gap')
        end)
        h:load(L)
        h:bind(unit,G); h:fire(event)
        h:added(unit,aura(21,98,12))
        assert(BjarkiLearn:GetContext(unit).defensiveWitness,'old actor has a positive witness')
        assert(BjarkiLearn:Forecast(G),'old actor resolves by GUID before change')
        h.clock=100.1; h:bind(unit,OTHER); checking=true
        h:fire(event); h:drain()
        local current=assert(BjarkiLearn:GetContext(unit))
        eq(current.actor,OTHER,'refresh binds the new actor')
        eq(current.defensiveWitness,nil,'previous witness stays with original actor')
        eq(BjarkiLearn:Forecast(OTHER).actor,OTHER,'new GUID resolves after refresh')
        h:healthy()
    end)
end
test('public GUID queries require one surviving readable alias',function()
    local h=setup({L})
    h:bind('focus',G); h:fire('PLAYER_FOCUS_CHANGED')
    local before=BjarkiLearn:Status().adapter
    local nativeIsPlayer=UnitIsPlayer
    UnitIsPlayer=function(unit)
        if unit=='target' then return false end
        return nativeIsPlayer(unit)
    end
    eq(BjarkiLearn:GetContext('target'),nil,'contradictory token rejected')
    eq(BjarkiLearn:Forecast('target'),nil,'contradictory token forecast rejected')
    eq(BjarkiLearn:GetContext(G).actor,G,'focus still confirms the GUID')
    eq(BjarkiLearn:Forecast(G).actor,G,'surviving focus permits GUID forecast')
    for _,unavailable in ipairs({
        function() return h.hidden end, function() return nil end,
        function() error('unavailable UnitGUID') end,
    }) do
        UnitGUID=function(unit)
            if unit=='focus' then return unavailable() end
            return h.units[unit]
        end
        for _,key in ipairs({'focus',G}) do
            eq(BjarkiLearn:GetContext(key),nil,'unverified identity has no public context')
            eq(BjarkiLearn:Forecast(key),nil,'unverified identity has no public forecast')
        end
    end
    eq(BjarkiLearn:GetContext('player').actor,h.units.player,'unrelated current player still resolves')
    local after=BjarkiLearn:Status().adapter
    eq(after.contexts,before.contexts,'queries cannot record observations')
    eq(after.gaps,before.gaps,'queries cannot change coverage')
    h:healthy()
end)
test('friendly casts appear as non-self positives and withhold learned scores',function()
    local h=T.new(paths,{L})
    h:bind('target',G); h.hostile.target=false; h:fire('PLAYER_TARGET_CHANGED')
    InCombatLockdown=function() return true end
    for tick=0,18 do
        h.clock=100+tick/8
        h.addons[L].Runtime:Update()
        if tick==4 then h:fire('UNIT_SPELLCAST_SUCCEEDED','target','Cast-Friendly',15487) end
    end
    eq(BjarkiLearn:GetContext('target').role,'friendly','readable ally')
    eq(BjarkiLearn:Status().core.families[4].otherPositive,1,'retained ally silence')
    assert(learnStatusText():match('silence:[^\n]*non%-self positives 1'),'status identifies the ally count as non-self')
    local silence=BjarkiLearn:Forecast('target').outputs[4]
    eq(silence.reason,'unsupported_non_self_coverage','friendly withholding reason')
    eq(silence.score,nil,'no learned score for ally')
    h:healthy()
end)
test('Learn disable unsubscribes; re-enable replays bounded actual publisher positives',function()
    local h=setup(); h:added('targettarget',aura(21,98,12))
    local old=h.addons[L].Runtime.adapter
    SlashCmdList.BJARKILEARN('disable')
    eq(BjarkiLearn:GetContext('target'),nil,'disabled public context absent')
    eq(BjarkiEvidenceV1.listeners['bjarkiLearn.aura-evidence'],nil,'disabled subscription removed')
    h.clock=101; h:added('targettarget',aura(22,100,12))
    eq(h:occurrence(G,22),nil,'disabled Learn receives no publication')
    assert(h:row(G),'independent CC still receives publication')
    SlashCmdList.BJARKILEARN('enable')
    assert(h.addons[L].Runtime.adapter~=old,'enable starts new adapter')
    consumers(h,G,22)
    eq(h:occurrence(G,22).at,101,'enable replay preserves source clock')
    eq(BjarkiLearn:Status().enabled,true,'public enabled state')
end)
test('positive-only omissions cannot erase witnesses or manufacture casts',function()
    local h=setup(); h:snapshot('targettarget',aura(21,98,12))
    local claim=h:row(G).claimID; local published=BjarkiEvidenceV1.stats.published
    h.clock=101; h:snapshot('targettarget',nil)
    h:fire('UNIT_AURA','targettarget',{removedAuraInstanceIDs={21}}); h:drain()
    eq(BjarkiEvidenceV1.stats.published,published,'empty/removal event publishes no negative')
    eq(h:row(G).claimID,claim,'absence cannot clear CC cooldown')
    eq(h:occurrence(G).expires,110,'absence cannot erase Learn positive witness')
    h.clock=111; h.addons[L].Runtime.adapter:Bind('target',111)
    local core=h.addons[L].Runtime.core
    local features=h.addons[L].Rules.Features(core.actors[G],111,core:_Evidence(G,111))
    eq(features[47],0,'expired witness does not establish current presence')
    eq(features[48],0,'expired witness is unknown rather than confirmed absence')
    eq(core.stats.casts or 0,0,'aura-only stream has zero cast outcomes')
    h:healthy()
end)
test('publisher gates reject friendly, untracked, harmful and unavailable observations',function()
    local h=setup()
    h.hostile.targettarget=false; h:added('targettarget',aura())
    h.hostile.targettarget=true; h:added('party1',aura())
    local harmful=aura(); harmful.isHelpful=false; h:added('targettarget',harmful)
    h.blocked.targettarget='secret'; h:snapshot('targettarget',aura())
    h.blocked.targettarget='error'; h:snapshot('targettarget',aura())
    eq(BjarkiEvidenceV1.stats.published,0,'ineligible observations never enter bridge')
    eq(h:row(G),nil,'no CC inference from unavailable observation')
    eq(h:occurrence(G),nil,'no Learn context from unavailable observation')
    h:healthy()
end)
test('bus and consumers reject negative schema; unsupported helpful spell is not self-cast evidence',function()
    local h=setup()
    eq(BjarkiEvidenceV1:Publish({source='bjarkiPortraits',kind='aura-negative',isHelpful=false,
        recipientGUID=G,unit='targettarget',spellId=22812,observedAt=100}),false,'closed bus schema')
    h:added('targettarget',aura(30,98,12,17))
    eq(BjarkiEvidenceV1.stats.published,1,'publisher permits readable positive outside inference allowlist')
    eq(h:row(G,17),nil,'CC does not promote arbitrary helpful recipient to caster')
    eq(h:occurrence(G,30),nil,'Learn ignores non-defensive family')
    h:healthy()
end)
test('a later positive snapshot supersedes elapsed timing on the same aura instance',function()
    local h=setup()
    h.clock=101; h:snapshot('targettarget',aura(41,89,15,5277))
    eq(BjarkiLearn:GetContext('target').defensiveWitness.expires,104,'first Evasion endpoint')
    h.clock=105
    local later=aura(41,nil,nil,5277)
    later.expirationTime,later.duration=h.hidden,h.hidden
    h:snapshot('targettarget',later)
    local ctx=assert(BjarkiLearn:GetContext('target'))
    eq(ctx.defensiveWitness.at,105,'new positive observation time')
    eq(ctx.defensiveWitness.expires,nil,'refresh duration unknown after old endpoint')
    eq(h.addons[L].Rules.Features(ctx,105)[48],1,'current positive remains known')
    h.clock=106; h:snapshot('targettarget',aura(41,103,15,5277))
    eq(BjarkiLearn:GetContext('target').defensiveWitness.expires,118,'readable refreshed timing')
    h:healthy()
end)
test('Learn-first optional addon load is a resilience probe with late connection',function()
    local h=setup({L,P,C})
    eq(h.addons[L].Runtime.adapter.stats.busConnected,true,'ADDON_LOADED connects late publisher bus')
    h:added('targettarget',aura(21,98,12)); consumers(h,G)
end)
test('publisher before consumers replays the actual publication',function()
    local h=setup({P})
    h:added('targettarget',aura(21,98,12))
    eq(#BjarkiEvidenceV1.listenerOrder,0,'publisher functions without subscribers')
    h.clock=101; h:load(C); h:load(L)
    consumers(h,G)
    eq(h:row(G).started,98,'replay keeps original inferred start')
    eq(h:occurrence(G).at,100,'Learn replay keeps original observation time')
end)
for _,order in ipairs({{L},{C,L},{P,L},{P,C}}) do
    test('optional absence '..table.concat(order,','),function()
        local h=setup(order)
        h.auras.targettarget={[22812]=aura(21,98,12)}
        h:added('targettarget',h.auras.targettarget[22812])
        h:fire('PLAYER_ENTERING_WORLD'); h:drain()
        if h.addons[L] then
            local status=learnStatusText()
            local subscription=BjarkiEvidenceV1 and 'subscribed' or 'unsubscribed'
            assert(status:find('shared evidence bus '..subscription,1,true),'status identifies bus subscription')
            if not h.addons[P] then
                assert(status:find('Portraits aura messages 0',1,true),'no deliveries from an absent publisher')
            else
                assert(status:match('Portraits aura messages [1-9]'),'status reports actual Portraits deliveries')
            end
        end
        if not h.addons[P] then
            eq(BjarkiEvidenceV1 and BjarkiEvidenceV1.stats.published or 0,0,'no publisher means no fabricated bus evidence')
            if h.addons[L] then eq(h:occurrence(G),nil,'Learn has no fabricated bridge witness') end
        else
            if h.addons[L] then assert(h:occurrence(G),'Learn works without CC') end
            if h.addons[C] then assert(h:row(G),'CC works without Learn') end
        end
        h:healthy()
    end)
end
assert(#failures==0,tostring(#failures)..' bridge case(s) failed:\n'..table.concat(failures,'\n'))
print('suite bridge: '..passed..' cases passed ('.._VERSION..')')
