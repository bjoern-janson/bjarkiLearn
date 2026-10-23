local addonName, ns = ...
local S = ns.Safe
local Main = {}
Main.__index = Main
ns.Main = Main

local EVENTS = { 'ADDON_LOADED', 'PLAYER_LOGOUT', 'PLAYER_ENTERING_WORLD',
    'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'UNIT_SPELLCAST_SUCCEEDED',
    'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED', 'PLAYER_ALIVE', 'PLAYER_DEAD' }
local function nowTime()
    local now = S.Number(S.Call(GetTime))
    if now and now >= 0 and now <= 100000000 then return now end
end
local function printLine(text)
    local chat = S.Table(DEFAULT_CHAT_FRAME)
    local write = chat and S.Field(chat, 'AddMessage')
    if type(write) == 'function' then pcall(write, chat, '|cff78c5ffbjarkiLearn:|r '..text) end
end
local function textValue(value)
    local text = S.String(value)
    if text then return text end
    local number = S.Number(value)
    if number then return tostring(number) end
    return 'unknown'
end

function Main.New()
    local self = setmetatable({ initialized = false, enabled = false, errors = 0,
        registrationErrors = {}, updates = 0, profileSamples = 0, maxUpdateMs = 0, lastUpdateMs = 0 }, Main)
    self.frame = CreateFrame('Frame')
    for _, event in ipairs(EVENTS) do
        local ok, registered = pcall(self.frame.RegisterEvent, self.frame, event)
        -- Legacy clients return nothing; an explicit failure grants no coverage.
        ok = ok and S.Readable(registered)
            and (registered == nil or S.Boolean(registered) == true)
        if event == 'UNIT_SPELLCAST_SUCCEEDED' then self.castRegistered = ok end
        if not ok then self.registrationErrors[#self.registrationErrors + 1] = event end
    end
    self.frame:SetScript('OnEvent', function(_, event, ...) self:Dispatch(event, ...) end)
    self.frame:SetScript('OnUpdate', function() self:Update() end)
    return self
end

function Main:InstallPublic()
    -- Other addons can inspect ordinary copies. No evidence-write or consumer
    -- authorization method is exported, and an existing global is respected.
    local existing = BjarkiLearn
    if not S.Readable(existing) or existing ~= nil then self.publicAvailable = false; return end
    local runtime = self
    local api = { protocol = 'bjarki-learn-v1', version = ns.Config.version, mode = 'shadow' }
    function api:Status() return runtime:Status() end
    function api:GetContext(unitOrGUID)
        if not runtime.enabled or runtime.faulted or not runtime.adapter then return nil end
        local actor, now = runtime.adapter:Resolve(unitOrGUID), nowTime()
        if actor and now then return ns.Copy(runtime.core:GetContext(actor, now)) end
    end
    function api:Forecast(unitOrGUID)
        if not runtime.enabled or runtime.faulted or not runtime.adapter then return nil end
        local actor, now = runtime.adapter:Resolve(unitOrGUID), nowTime()
        if actor and now then return ns.Copy(runtime.core:Forecast(actor, now)) end
    end
    BjarkiLearn = api
    self.publicAvailable = true
end

function Main:Initialize()
    if self.initialized then return end
    self.core = ns.Core.New()
    local saved = S.Table(bjarkiLearnDB)
    local enabled = saved and S.Boolean(S.Field(saved, 'enabled'))
    if saved then self.core:Restore(S.Field(saved, 'learning')) end
    self.initialized = true
    self:InstallPublic()
    self:SetEnabled(enabled ~= false)
end

function Main:SetEnabled(enabled)
    if not self.initialized then return end
    enabled = enabled == true
    if enabled == self.enabled and not self.faulted then return end
    local now = nowTime()
    if self.adapter then self.adapter:Stop() end
    if now then self.core:ResetSession(now) end
    self.enabled, self.faulted, self.lastWork = enabled, false, nil
    if enabled then
        self.adapter = ns.Adapter.New(self.core)
        self.adapter:SetRegistered(self.castRegistered)
        if now then self.adapter:Tick(now); self.adapter:ConnectBus(now) end
    else self.adapter = nil end
end

function Main:Save()
    if not self.initialized then return end
    bjarkiLearnDB = { schema = 1, enabled = self.enabled, learning = self.core:Export() }
end

function Main:Fault()
    self.errors = math.min(2147483647, self.errors + 1)
    self.faulted = true
    if self.adapter then pcall(self.adapter.Stop, self.adapter) end
    printLine('collection paused after an internal error; /blearn status shows the state. Reload to retry.')
end

function Main:Dispatch(event, ...)
    if event == 'ADDON_LOADED' and not self.initialized then
        local name = S.String(...)
        if name == addonName then
            local ok = pcall(self.Initialize, self)
            if not ok then self:Fault() end
        end
        return
    end
    if not self.initialized then return end
    if event == 'PLAYER_LOGOUT' then
        local ok = pcall(self.Save, self)
        if not ok then self.errors = math.min(2147483647, self.errors + 1) end
    elseif self.enabled and not self.faulted and self.adapter then
        local ok = pcall(self.adapter.OnEvent, self.adapter, event, ...)
        if not ok then self:Fault() end
    end
end

function Main:Update()
    if not self.initialized or not self.enabled or self.faulted then return end
    local now = nowTime()
    if not now then self.adapter:Gap('unreadable-clock'); return end
    local start = S.Number(S.Call(debugprofilestop))
    local ok = pcall(function()
        self.adapter:Tick(now)
        local combat = S.Boolean(S.Call(InCombatLockdown))
        if combat == nil then
            if not self.combatUnknown then self.adapter:Gap('unreadable-combat') end
            self.combatUnknown = true
        else self.combatUnknown = false end
        if not self.lastWork or now < self.lastWork or now - self.lastWork >= .1 then
            self.lastWork = now
            -- Unknown combat state defers training. No update is performed
            -- from a native combat-event handler.
            self.core:Tick(now, combat)
            self.updates = math.min(2147483647, self.updates + 1)
        end
    end)
    if not ok then self:Fault(); return end
    local finish = S.Number(S.Call(debugprofilestop))
    if start and finish and finish >= start then
        self.profileSamples = math.min(2147483647, self.profileSamples + 1)
        self.lastUpdateMs = finish - start
        self.maxUpdateMs = math.max(self.maxUpdateMs, self.lastUpdateMs)
    end
end

function Main:Status()
    return {
        version = ns.Config.version, mode = 'shadow', initialized = self.initialized,
        enabled = self.enabled, faulted = self.faulted == true, castRegistered = self.castRegistered == true,
        publicAvailable = self.publicAvailable == true, errors = self.errors, updates = self.updates,
        maxUpdateMs = self.maxUpdateMs, lastUpdateMs = self.lastUpdateMs,
        profilingAvailable = self.profileSamples > 0,
        registrationErrors = ns.Copy(self.registrationErrors),
        adapter = self.adapter and ns.Copy(self.adapter:Status()) or nil,
        core = self.core and ns.Copy(self.core:Status()) or nil,
    }
end

function Main:PrintStatus()
    local status = self:Status()
    printLine(ns.Config.version..' | shadow | '..(self.enabled and 'enabled' or 'disabled')
        ..(self.faulted and ' | paused after error' or '')..' | native cast registration '
        ..(self.castRegistered and 'available' or 'unavailable'))
    if status.core then
        local core = status.core
        printLine('actors '..textValue(core.actors)..', occurrences '..textValue(core.occurrences)
            ..', retained examples '..textValue(core.examples)..'; model '..textValue(core.modelVersion)
            ..(core.training and ' rebuilding' or ''))
        if type(core.families) == 'table' then
            for _, family in ipairs(core.families) do
                local line = textValue(family.family)..': player + '..textValue(family.positive)
                    ..' / - '..textValue(family.negative)..' / unknown '..textValue(family.censored)
                    ..'; enemy positives '..textValue(family.otherPositive)
                if S.Number(family.scored) and family.scored > 0 then
                    line = line..'; '..family.scored..' paired forecasts, Brier neural/linear/frequency '
                        ..string.format('%.4f/%.4f/%.4f', family.neuralLoss, family.linearLoss, family.frequencyLoss)
                end
                printLine(line)
            end
        end
    end
    if status.adapter then
        local adapter = status.adapter
        printLine('readable cast deliveries '..textValue(adapter.casts)..', positive aura messages '
            ..textValue(adapter.auras)..', coverage gaps '..textValue(adapter.gaps)
            ..'; Portraits bridge '..(adapter.busConnected and 'connected' or 'absent'))
    end
    printLine('player-only negative coverage; enemy absence remains unknown. No forecasts change the interface.')
    local profiling = self.profileSamples > 0 and ('update peak '..string.format('%.3f', self.maxUpdateMs)..' ms')
        or 'CPU profiling unavailable'
    printLine(profiling..'; errors '..self.errors..'. /blearn inspect player|target|focus')
end

function Main:Inspect(unit)
    if not self.enabled or self.faulted or not self.adapter then printLine('learner is disabled or paused.'); return end
    local actor, now = self.adapter:Resolve(unit), nowTime()
    if not actor or not now then printLine('no current readable binding for '..unit..'.'); return end
    local context = self.core:GetContext(actor, now)
    if not context then printLine('context is unavailable or stale.'); return end
    printLine(unit..': '..textValue(context.class)..', '..textValue(context.role)..'; predictions remain shadow diagnostics.')
    local forecast = self.core:Forecast(actor, now)
    if not forecast then printLine('no current forecast.'); return end
    printLine('cast-delivery forecast; scores are diagnostic rankings, not calibrated probabilities.')
    if forecast.reason then printLine('withheld: '..textValue(forecast.reason)) end
    local outputs = forecast.outputs
    if type(outputs) == 'table' then
        for i, family in ipairs(ns.Rules.families) do
            local output = outputs[i] or outputs[family]
            if type(output) == 'table' then
                local score = S.Number(output.score)
                local candidate = output.candidate and output.candidate.status or 'unknown'
                printLine(family..': '..textValue(candidate)..'; '..(score and string.format('score %.3f', score) or 'withheld')
                    ..' ('..textValue(output.reason or output.status)..')')
            end
        end
    end
end

function Main:Command(raw)
    local command = S.String(raw) or ''
    local action, rest = command:lower():match('^%s*(%S*)%s*(.-)%s*$')
    if not self.initialized then printLine('not initialized.'); return end
    if action == '' or action == 'status' then self:PrintStatus()
    elseif action == 'inspect' then
        local unit = rest == '' and 'target' or rest
        if unit ~= 'player' and unit ~= 'target' and unit ~= 'focus' then
            printLine('use /blearn inspect player|target|focus.'); return
        end
        self:Inspect(unit)
    elseif action == 'enable' or action == 'disable' then
        self:SetEnabled(action == 'enable'); self:Save()
        printLine(self.enabled and 'shadow learning enabled.' or 'learning disabled; retained examples preserved.')
    elseif action == 'reset' and rest == '' then
        local enabled = self.enabled
        if self.adapter then self.adapter:Stop() end
        self.core, self.adapter, self.enabled, self.faulted = ns.Core.New(), nil, false, false
        self:SetEnabled(enabled); self:Save()
        printLine('learner examples and adaptation cleared.')
    else printLine('/blearn status | inspect player|target|focus | enable | disable | reset') end
end

ns.Runtime = Main.New()
SLASH_BJARKILEARN1 = '/blearn'
SLASH_BJARKILEARN2 = '/bjarkilearn'
SlashCmdList.BJARKILEARN = function(command) ns.Runtime:Command(command) end
