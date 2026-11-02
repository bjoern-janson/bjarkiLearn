-- Run from the Learn root. The fixture loads the real TOC and dispatches native events.
local T = dofile('tests/suite/support.lua')
local failures, passed = {}, 0
local function test(name, run)
    local ok, why = pcall(run)
    if ok then passed = passed + 1 else failures[#failures + 1] = name..': '..tostring(why) end
end

local function delivery(name, step, before, fire, expected)
    test(name, function()
        local h = T.new({bjarkiLearn='.'})
        InCombatLockdown = function() return true end
        if before then before(h) end
        local runtime = h:load('bjarkiLearn').Runtime
        for i=0,18 do
            h.clock = 100 + i/8
            runtime:Update()
            if step == i then fire(h) end
        end
        local status = BjarkiLearn:Status().core
        local result = {}
        for i,family in ipairs(status.families) do
            T.equal(family.negative + family.positive + family.censored, 1, 'one player window')
            result[i] = family.negative == 1 and '-' or family.positive == 1 and '+' or '?'
        end
        T.equal(table.concat(result), expected, 'player labels in family order')
        h:healthy()
    end)
end
local function npc(h)
    h.units.target = 'Creature-0-1-2-3-4-5'
    UnitIsPlayer = function(unit) return unit == 'player' end
end
local function cast(unit, id, spell)
    return function(h)
        h:fire('UNIT_SPELLCAST_SUCCEEDED', unit or h.hidden, id or h.hidden, spell or h.hidden)
    end
end
local silence = 15487
for _,spell in ipairs({123456, silence}) do
    delivery('NPC cast '..spell, 4, npc, cast('target', 'Cast-npc', spell), '------')
end
delivery('readable creature GUID with unavailable player flag', 4, function(h)
    npc(h)
    UnitIsPlayer = function(unit) if unit == 'target' then return h.hidden end return unit == 'player' end
end, cast('target', nil, silence), '------')
delivery('unknown spell on a proven NPC', 4, npc, cast('target', nil, nil), '------')
delivery('unreadable cast ID inside horizon', 4, nil, cast('player', nil, silence), '---?--')
delivery('unreadable cast ID exactly at anchor', 0, nil, cast('player', nil, silence), '------')
delivery('unreadable cast ID exactly at deadline', 16, nil, cast('player', nil, silence), '---?--')
delivery('unreadable cast ID during grace', 17, nil, cast('player', nil, silence), '------')
delivery('unreadable spell inside horizon', 4, nil, cast('player', nil, nil), '??????')
delivery('unreadable spell during grace', 17, nil, cast('player', nil, nil), '------')
delivery('unreadable unit and spell', 4, nil, cast(nil, nil, nil), '??????')
delivery('unreadable GUID and player flag', 4, function(h)
    h.units.target = h.hidden
    UnitIsPlayer = function(unit) if unit == 'target' then return h.hidden end return unit == 'player' end
end, cast('target', nil, nil), '??????')
delivery('missing actor with a known family', 4, nil, cast('target', nil, silence), '---?--')
delivery('missing actor with an unregistered spell', 4, nil, cast('target', nil, 123456), '------')
delivery('missing unit with a known family', 4, nil, cast(nil, nil, silence), '---?--')
delivery('identified positive survives a global delivery gap', 4, nil, function(h)
    cast(nil, nil, nil)(h)
    cast('player', 'Cast-positive', silence)(h)
end, '???+??')

test('native player aura timing on repeated positive observations', function()
    local h = T.new({bjarkiLearn='.'})
    h.auras.player = {[5277]=T.aura(41, 89, 15, 5277)}
    local learn = h:load('bjarkiLearn')
    local function checkTiming(at, expiry, known)
        local ctx = assert(BjarkiLearn:GetContext('player'))
        T.equal(ctx.defensiveWitness.expires, expiry, 'native witness endpoint')
        T.equal(learn.Rules.Features(ctx, at)[48], known, 'defensive witness feature')
    end
    h.clock = 102
    h.auras.player[5277].expirationTime, h.auras.player[5277].duration = h.hidden, h.hidden
    learn.Runtime:Update()
    checkTiming(102, 104, 1) -- The previous endpoint is still in the future.
    checkTiming(104, 104, 0) -- With no new observation, it still expires.
    h.clock = 104
    learn.Runtime:Update()
    checkTiming(104, nil, 1) -- A current positive supersedes the old endpoint.
    checkTiming(113, nil, 0) -- Untimed observations retain their normal recency limit.
    h.clock = 105
    h.auras.player[5277] = T.aura(41, 103, 15, 5277)
    learn.Runtime:Update()
    checkTiming(105, 118, 1)
    h:healthy()
end)
test('upgrade discards old evidence and keeps the disabled preference across reload', function()
    local oldKey = 'learn1/forever16001-provisional2/features48-v3/cast-delivery-v2/h2/'
        ..'player-combat-v1/self-aura-v1/retention-v1/replay-v2/mlp12-sgd4-v1'
    local x = {}
    for i=1,48 do x[i] = 0 end
    local oldRow = {regime='player', x=x, y={1,0,0,0,0,0}, mask={true,true,true,true,true,true}}
    local function loadSave(save)
        local h = T.new({bjarkiLearn='.'})
        bjarkiLearnDB = save
        InCombatLockdown = function() return true end
        return h, h:load('bjarkiLearn').Runtime
    end
    local h, runtime = loadSave({schema=1, enabled=false, learning={schema=1,compat=oldKey,examples={oldRow}}})
    local status = BjarkiLearn:Status()
    T.equal(status.restoreReason, 'incompatible', '0.1.8 corpus rejected')
    T.equal(status.enabled, false, 'upgrade preserves disabled setting')
    T.equal(status.core.examples, 0, 'old row discarded')
    T.equal(status.core.pending, 0, 'no pending collection')
    T.equal(status.core.training, false, 'no training from old save')
    T.equal(BjarkiLearn:Forecast('player'), nil, 'disabled forecast')
    h:fire('PLAYER_LOGOUT')
    T.equal(bjarkiLearnDB.enabled, false, 'disabled setting saved')
    T.equal(#bjarkiLearnDB.learning.examples, 0, 'old row does not survive logout')
    h, runtime = loadSave(bjarkiLearnDB)
    T.equal(BjarkiLearn:Status().restoreReason, nil, 'fresh empty save compatible')
    T.equal(BjarkiLearn:Status().enabled, false, 'disabled setting reloaded')
    SlashCmdList.BJARKILEARN('enable')
    for i=0,18 do
        h.clock = 100 + i/8
        runtime:Update()
        if i == 4 then cast('player', 'Cast-new', silence)(h) end
    end
    T.equal(BjarkiLearn:Status().core.families[4].positive, 1, 'new positive collected')
    SlashCmdList.BJARKILEARN('disable')
    h:fire('PLAYER_LOGOUT')
    h = loadSave(bjarkiLearnDB)
    status = BjarkiLearn:Status()
    T.equal(status.restoreReason, nil, 'new corpus compatible')
    T.equal(status.enabled, false, 'nonempty save retains disabled preference')
    T.equal(status.core.families[4].positive, 1, 'new positive restored')
    T.equal(status.core.families[1].positive, 0, 'discarded positive does not return')
    h:healthy()
end)
assert(#failures == 0, table.concat(failures, '\n'))
print('evidence scope: '..passed..' cases passed ('.._VERSION..')')
