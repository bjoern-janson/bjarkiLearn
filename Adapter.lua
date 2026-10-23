local _, ns = ...
local S = ns.Safe
local Adapter = {}
Adapter.__index = Adapter
ns.Adapter = Adapter

local UNITS = { 'player', 'target', 'focus' }
local TRACKED = { player = true, target = true, focus = true }
local BUS_KEY = 'bjarkiLearn.aura-evidence'
local function guid(value)
    local v = S.String(value)
    if v and #v <= 128 and v:match('^Player%-[%w%-]+$') then return v end
end
local function stamp(value)
    local v = S.Number(value)
    if v and v >= 0 and v <= 100000000 then return v end
end
local function identifier(value)
    local v = S.Number(value)
    if v and v > 0 and v <= 9999999 and v == math.floor(v) then return v end
end
local function castIdentity(value)
    local v = S.String(value)
    if v and #v > 0 and #v <= 128 then return v end
end
local function class(unit)
    local token = S.String(S.Call(UnitClassBase, unit))
    if not token and type(UnitClass) == 'function' then
        local ok, _, value = pcall(UnitClass, unit)
        if ok then token = S.String(value) end
    end
    if token and #token <= 16 and token:match('^[A-Z]+$') then return token end
end
local function fraction(value, maximum)
    value, maximum = S.Number(value), S.Number(maximum)
    if value and maximum and value >= 0 and maximum > 0 then
        return math.min(1, value / maximum)
    end
end
local function form(unit, classToken)
    if classToken ~= 'DRUID' or S.Boolean(S.Call(UnitIsDeadOrGhost, unit)) ~= false
        or type(UnitPowerType) ~= 'function' then return nil end
    local ok, _, raw = pcall(UnitPowerType, unit)
    local token = ok and S.String(raw) or nil
    if token == 'ENERGY' then return 'cat' end
    if token == 'RAGE' then return 'bear' end
end

function Adapter.New(core)
    return setmetatable({ core = core, bindings = {}, registered = false, stopped = false,
        stats = { contexts = 0, casts = 0, unknownSpells = 0, rejected = 0,
            gaps = 0, auras = 0, busErrors = 0, busConnected = false, registered = false } }, Adapter)
end

function Adapter:Gap(reason, actor)
    self.stats.gaps = self.stats.gaps + 1
    self.core:Gap(reason, actor)
end

function Adapter:SetRegistered(value)
    self.registered = value == true
    self.stats.registered = self.registered
    if not self.registered then self:Gap('cast-registration') end
    self:UpdateCoverage()
end

function Adapter:UpdateCoverage()
    local enabled = not self.stopped and self.registered and self.bindings.player ~= nil
    if enabled ~= self.coverage then
        self.coverage = enabled
        self.core:SetCoverage(enabled)
    end
end

function Adapter:Bind(unit, now)
    local current = guid(S.Call(UnitGUID, unit))
    -- A readable contradiction is disqualifying. Unknown type is permitted
    -- when the GUID itself establishes player identity.
    if S.Boolean(S.Call(UnitIsPlayer, unit)) == false then current = nil end
    local previous = self.bindings[unit]
    self.bindings[unit] = current
    if previous and previous ~= current then
        local stillBound = false
        for _, other in ipairs(UNITS) do
            if self.bindings[other] == previous then stillBound = true end
        end
        -- Losing a target/focus alias does not break a surviving player's
        -- observation stream. Losing the player binding itself does.
        if unit == 'player' or not stillBound then self:Gap('identity-change', previous) end
        if not stillBound then self.core:Context({ actor = previous, at = now, bound = false }) end
    end
    if not current then
        if unit == 'player' then self:UpdateCoverage() end
        return nil
    end
    local source = unit
    if unit ~= 'player' and self.bindings.player == current then source = 'player' end
    local classToken = class(source)
    local hostile = S.Boolean(S.Call(UnitCanAttack, 'player', source))
    local isSelf = source == 'player'
    local role = isSelf and 'self' or (hostile == true and 'hostile' or (hostile == false and 'friendly' or 'unknown'))
    self.core:Context({ actor = current, class = classToken, role = role,
        combat = S.Boolean(S.Call(UnitAffectingCombat, source)),
        health = fraction(S.Call(UnitHealth, source), S.Call(UnitHealthMax, source)),
        power = fraction(S.Call(UnitPower, source), S.Call(UnitPowerMax, source)),
        form = form(source, classToken), at = now, regime = isSelf and 'player' or 'other', bound = true })
    self.stats.contexts = self.stats.contexts + 1
    if unit == 'player' then self:UpdateCoverage() end
    return current
end

function Adapter:Tick(now)
    now = stamp(now)
    if self.stopped or not now then return end
    if self.lastTick and (now < self.lastTick or now - self.lastTick > .5) then self:Gap('scheduler-gap') end
    self.lastTick = now
    if self.lastRefresh and now >= self.lastRefresh and now - self.lastRefresh < .25 then return end
    self.lastRefresh = now
    for _, unit in ipairs(UNITS) do self:Bind(unit, now) end
end

function Adapter:Resolve(unitOrGUID)
    local value = S.String(unitOrGUID)
    if not value then return nil end
    if TRACKED[value] then return self.bindings[value] end
    value = guid(value)
    if value then
        for _, unit in ipairs(UNITS) do if self.bindings[unit] == value then return value end end
    end
end

function Adapter:OnCast(rawUnit, rawCast, rawSpell, now)
    local unit = S.String(rawUnit)
    if not unit then self.stats.rejected = self.stats.rejected + 1; self:Gap('unreadable-unit'); return end
    if not TRACKED[unit] then return end
    local actor = self:Bind(unit, now)
    local spellID = identifier(rawSpell)
    if not actor or not spellID then
        self.stats.rejected = self.stats.rejected + 1
        self:Gap(not actor and 'unreadable-actor' or 'unreadable-spell', actor)
        return
    end
    local family = ns.Rules.Classify(spellID)
    if not family then self.stats.unknownSpells = self.stats.unknownSpells + 1; return end
    local id = castIdentity(rawCast)
    if not id then self.stats.rejected = self.stats.rejected + 1; self:Gap('unreadable-cast', actor); return end
    self.core:Cast({ actor = actor, id = id, family = family, at = now, revision = 1, source = 'native-cast' })
    self.stats.casts = self.stats.casts + 1
end

function Adapter:OnAura(raw)
    if self.stopped or not S.Table(raw) then return end
    local field = S.Field
    if S.String(field(raw, 'source')) ~= 'bjarkiPortraits'
        or S.String(field(raw, 'kind')) ~= 'aura-positive'
        or S.Boolean(field(raw, 'isHelpful')) ~= true then return end
    local recipient = guid(field(raw, 'recipientGUID'))
    local spellID = identifier(field(raw, 'spellId'))
    local observed = stamp(field(raw, 'observedAt'))
    if not recipient or not spellID or not observed then self.stats.rejected = self.stats.rejected + 1; return end
    if not ns.Rules.SelfDefensive[spellID] then return end
    -- This positive-only channel contributes context, never a cast outcome.
    -- Preserve native identity and first-sighting metadata for the core.
    local expires, duration = stamp(field(raw, 'expirationTime')), S.Number(field(raw, 'duration'))
    if duration and (duration <= 0 or duration > 300) then duration = nil end
    local instance = identifier(field(raw, 'auraInstanceID'))
    if not instance then self.stats.rejected = self.stats.rejected + 1; return end
    self.core:Aura({ recipient = recipient, id = tostring(instance),
        spellID = spellID, at = observed, expires = expires, duration = duration,
        newApplication = S.Boolean(field(raw, 'newApplication')) == true })
    self.stats.auras = self.stats.auras + 1
end

function Adapter:ConnectBus(now)
    if self.stopped then return false end
    if self.bus then return true end
    now = stamp(now)
    local bus = S.Table(BjarkiEvidenceV1)
    if not now or not bus or S.String(S.Field(bus, 'protocol')) ~= 'bjarki-positive-aura-v1'
        or S.Number(S.Field(bus, 'schema')) ~= 1 then return false end
    local subscribe, unsubscribe = S.Field(bus, 'Subscribe'), S.Field(bus, 'Unsubscribe')
    if type(subscribe) ~= 'function' or type(unsubscribe) ~= 'function' then return false end
    self.callback = self.callback or function(record) self:OnAura(record) end
    local ok, result = pcall(subscribe, bus, BUS_KEY, self.callback, now)
    if not ok or S.Boolean(result) ~= true then self.stats.busErrors = self.stats.busErrors + 1; return false end
    self.bus, self.unsubscribe = bus, unsubscribe
    self.stats.busConnected = true
    return true
end

function Adapter:DisconnectBus()
    local bus, unsubscribe = self.bus, self.unsubscribe
    self.bus, self.unsubscribe = nil, nil
    self.stats.busConnected = false
    if bus and unsubscribe then
        local ok = pcall(unsubscribe, bus, BUS_KEY)
        if not ok then self.stats.busErrors = self.stats.busErrors + 1 end
    end
end

function Adapter:OnEvent(event, ...)
    if self.stopped then return end
    local now = stamp(S.Call(GetTime))
    if not now then self:Gap('unreadable-clock'); return end
    if event == 'UNIT_SPELLCAST_SUCCEEDED' then
        local unit, id, spell = ...
        self:OnCast(unit, id, spell, now)
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- Session reset clears the core's occurrence projection. A fresh
        -- subscription asks the unchanged v1 bus for its bounded recent
        -- positives again; an identical retained subscription would not replay.
        self:DisconnectBus()
        self.core:ResetSession(now)
        self.bindings, self.lastTick, self.lastRefresh = {}, nil, nil
        self:UpdateCoverage(); self:Tick(now); self:ConnectBus(now)
    elseif event == 'PLAYER_TARGET_CHANGED' then self:Bind('target', now)
    elseif event == 'PLAYER_FOCUS_CHANGED' then self:Bind('focus', now)
    elseif event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_REGEN_DISABLED'
        or event == 'PLAYER_ALIVE' or event == 'PLAYER_DEAD' then
        for _, unit in ipairs(UNITS) do self:Bind(unit, now) end
    elseif event == 'ADDON_LOADED' then self:ConnectBus(now) end
end

function Adapter:Stop()
    self.stopped = true
    self:Gap('disabled')
    self:DisconnectBus()
    self:UpdateCoverage()
end

function Adapter:Status()
    local out = {}
    for key, value in pairs(self.stats) do out[key] = value end
    out.playerBound, out.coverage = self.bindings.player ~= nil, self.coverage == true
    return out
end
