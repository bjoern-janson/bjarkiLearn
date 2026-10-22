-- Small, explicit WoW boundary model. No combat outcomes are generated here.
WoW = { frames = {}, messages = {}, clock = 0, units = {}, rejectedEvents = {}, combat = false }
local W = WoW
function W.Reset()
    W.clock, W.combat, W.messages, W.rejectedEvents = 0, false, {}, {}
    W.units = {
        player = { guid = 'Player-1-self', class = 'PRIEST', combat = true, health = 80, maxHealth = 100,
            power = 50, maxPower = 100, powerToken = 'MANA', dead = false },
        target = { guid = 'Player-1-enemy', class = 'DRUID', hostile = true, combat = true,
            health = 60, maxHealth = 100, power = 20, maxPower = 100, powerToken = 'ENERGY', dead = false },
    }
    W.secret = setmetatable({}, { __index = function() error('secret indexed') end,
        __tostring = function() error('secret formatted') end })
end
W.Reset()
function issecretvalue(value) return rawequal(value, W.secret) end
function issecrettable(value) return rawequal(value, W.secret) end
function canaccessvalue(value) return not rawequal(value, W.secret) end
function GetTime() return W.clock end
function InCombatLockdown() return W.combat end
local function unitField(unit, key)
    local record = W.units[unit]
    return record and record[key]
end
function UnitGUID(unit) return unitField(unit, 'guid') end
function UnitClassBase(unit) return unitField(unit, 'class') end
function UnitClass(unit) return unitField(unit, 'class'), unitField(unit, 'class') end
function UnitCanAttack(_, unit) return unitField(unit, 'hostile') end
function UnitIsPlayer(unit) return W.units[unit] ~= nil end
function UnitAffectingCombat(unit) return unitField(unit, 'combat') end
function UnitHealth(unit) return unitField(unit, 'health') end
function UnitHealthMax(unit) return unitField(unit, 'maxHealth') end
function UnitPower(unit) return unitField(unit, 'power') end
function UnitPowerMax(unit) return unitField(unit, 'maxPower') end
function UnitPowerType(unit) return 0, unitField(unit, 'powerToken') end
function UnitIsDeadOrGhost(unit) return unitField(unit, 'dead') end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event)
        if W.rejectedEvents[event] then error('unsupported event') end
        self.events[event] = true
    end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(kind, callback) self.scripts[kind] = callback end
    function frame:Fire(event, ...)
        if self.events[event] and self.scripts.OnEvent then self.scripts.OnEvent(self, event, ...) end
    end
    function frame:Update(elapsed)
        if self.scripts.OnUpdate then self.scripts.OnUpdate(self, elapsed) end
    end
    W.frames[#W.frames + 1] = frame
    return frame
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) W.messages[#W.messages + 1] = text end }
SlashCmdList = {}
