-- Ordinary Lua client API fixture. All publisher, bus and consumer code is shipped code.
local M = {}
-- WoW exposes the Lua 5.1 global even when the offline interpreter is 5.4.
unpack = unpack or table.unpack
function M.equal(actual, expected, label)
    assert(actual == expected, (label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
function M.aura(instance, started, duration, spell)
    return {spellId=spell or 22812,isHelpful=true,auraInstanceID=instance or 21,
        expirationTime=started and duration and started+duration,duration=duration}
end
function M.new(paths, order)
    local H = {clock=100,frames={},timers={},auras={},blocked={},hostile={},units={player='Player-1-Self'},addons={}}
    -- Each case gets new namespaces and globals; no old subscription or saved setting survives.
    BjarkiEvidenceV1, BjarkiLearn, BjarkiPortraitsDB, bjarkiCCDB, bjarkiLearnDB = nil,nil,nil,nil,nil
    PlayerFrame, TargetFrame, FocusFrame, PetFrame, TargetFrameToT, FocusFrameToT = nil,nil,nil,nil,nil,nil
    hooksecurefunc, UnitFramePortrait_Update, UnitFrame_SetUnit = nil,nil,nil
    AuraContainerSortMethod, AuraContainerSortDirection = nil,nil
    issecretvalue=function(value) return value==H.hidden end
    issecrettable=issecretvalue
    canaccessvalue=function(value) return value~=H.hidden end
    H.hidden={}
    GetTime=function() return H.clock end
    InCombatLockdown=function() return false end
    GetBuildInfo=function() return '1.60.1','70425','Oct 16 2026',16001 end
    UnitGUID=function(unit) return H.units[unit] end
    UnitIsPlayer=function(unit) return H.units[unit]~=nil end
    UnitExists=UnitIsPlayer
    UnitIsUnit=function(a,b) return H.units[a]~=nil and H.units[a]==H.units[b] end
    UnitCanAttack=function(_,unit) return H.hostile[unit]==true end
    UnitName=function(unit) return H.units[unit] and unit end
    UnitClassBase=function() return 'DRUID' end
    UnitAffectingCombat=function() return true end
    UnitIsDeadOrGhost=function() return false end
    UnitPowerType=function() return 0,'MANA' end
    UnitHealth=function() return 100 end; UnitHealthMax=UnitHealth
    UnitPower=function() return 50 end; UnitPowerMax=UnitHealth
    C_NamePlate={GetNamePlateForUnit=function() return nil end}
    C_Spell={GetSpellTexture=function() return 135963 end}
    C_Texture={GetAtlasInfo=function() return nil end}
    C_UnitAuras={GetAuraDataByIndex=function() return nil end,GetUnitAuraBySpellID=function(unit,id)
        if H.blocked[unit]=='error' then error('modeled unavailable aura query') end
        if H.blocked[unit]=='secret' then return H.hidden end
        return H.auras[unit] and H.auras[unit][id]
    end}
    C_Timer={After=function(delay,callback) H.timers[#H.timers+1]={delay=delay,callback=callback} end}
    DEFAULT_CHAT_FRAME={AddMessage=function() end}
    STANDARD_TEXT_FONT='font.ttf'; UISpecialFrames={}; SlashCmdList={}
    local methods={}
    for _,name in ipairs({'SetSize','SetWidth','SetHeight','SetPoint','ClearAllPoints','SetAllPoints',
        'SetTextColor','SetFont','SetJustifyH','SetTexCoord','SetTexture','SetFrameStrata','SetMovable',
        'SetClampedToScreen','RegisterForDrag','EnableMouse','SetBackdrop','SetBackdropColor',
        'SetBackdropBorderColor','SetDrawEdge','SetHideCountdownNumbers','SetReverse','SetOwner',
        'AddLine','SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetThumbTexture',
        'StartMoving','StopMovingOrSizing','SetAutoFocus','SetMultiLine','SetFontObject','HighlightText',
        'SetFocus','SetScrollChild','SetMaxLetters','SetColorTexture','SetVertexColor','SetAtlas'}) do
        methods[name]=function() end
    end
    function methods:SetScript(event,fn) self.scripts[event]=fn end
    function methods:RegisterEvent(event) self.events[event]=true end
    function methods:RegisterUnitEvent(event,a,b)
        self.events[event]={[a]=true}; if b then self.events[event][b]=true end
    end
    function methods:SetText(value) self.text=value end
    function methods:SetChecked(value) self.checked=value end
    function methods:GetChecked() return self.checked end
    function methods:SetValue(value) self.value=value end
    function methods:GetCenter() return 500,400 end
    function methods:GetLeft() return 450 end; function methods:GetRight() return 550 end
    function methods:GetTop() return 450 end; function methods:GetBottom() return 350 end
    function methods:GetEffectiveScale() return 1 end
    function methods:GetFrameLevel() return self.level or 1 end
    function methods:SetFrameLevel(value) self.level=value end
    function methods:IsShown() return self.shown end; methods.IsVisible=methods.IsShown
    function methods:Hide() self.shown=false end
    function methods:Show() self.shown=true end
    function methods:SetShown(value) self.shown=value end
    function methods:SetAlpha(value) self.alpha=value end
    function methods:SetCooldown(start,duration) assert(type(start)=='number' and type(duration)=='number') end
    local function object(kind,name,parent)
        local f=setmetatable({kind=kind,parent=parent,scripts={},events={},shown=true},{__index=methods})
        H.frames[#H.frames+1]=f
        if name then _G[name]=f end
        return f
    end
    function methods:CreateFontString() return object('FontString',nil,self) end
    function methods:CreateTexture() return object('Texture',nil,self) end
    CreateFrame=object; UIParent=object('Frame','UIParent')
    function H:fire(event,...)
        local unit=(...)
        -- Snapshot registered frames, as event dispatch does not run a newly created frame twice.
        local limit=#self.frames
        for i=1,limit do
            local f=self.frames[i]; local registered=f.events[event]
            if registered==true or (type(registered)=='table' and registered[unit]) then
                if f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end
            end
        end
    end
    function H:drain()
        local pending=self.timers; self.timers={}
        for _,timer in ipairs(pending) do timer.callback() end
        assert(#self.timers==0,'fixture does not permit hidden self-polling')
    end
    function H:load(name)
        local path=assert(paths[name],name..' path required')
        local ns,seen={},{}
        for line in io.lines(path..'/'..name..'.toc') do
            local file=line:match('^%s*([%w_]+%.lua)%s*$')
            if file then
                assert(not seen[file],'duplicate TOC module '..file); seen[file]=true
                assert(loadfile(path..'/'..file))(name,ns)
            end
        end
        assert(seen['Main.lua'],'TOC has no Main.lua')
        self.addons[name]=ns
        self:fire('ADDON_LOADED',name)
        return ns
    end
    function H:bind(unit,guid)
        self.units[unit]=guid; self.hostile[unit]=true
    end
    function H:added(unit,aura)
        self:fire('UNIT_AURA',unit,{addedAuras={aura}})
        self:drain()
    end
    function H:snapshot(unit,aura)
        self.auras[unit]=aura and {[aura.spellId]=aura} or {}
        self:fire('UNIT_AURA',unit,{isFullUpdate=true})
        self:drain()
    end
    function H:row(guid,spell)
        local cc=self.addons.bjarkiCC
        if not cc then return nil end
        for _,row in ipairs(cc.model:GetCooldowns(self.clock,nil,true)) do
            if row.guid==guid and row.spellID==(spell or 22812) then return row end
        end
    end
    function H:occurrence(guid,id)
        return self.addons.bjarkiLearn.Runtime.core.occurrences['aura:'..guid..':'..tostring(id or 21)]
    end
    function H:healthy()
        if BjarkiEvidenceV1 then M.equal(BjarkiEvidenceV1.stats.errors,0,'bus callback errors') end
        local learn=self.addons.bjarkiLearn
        if learn then M.equal(learn.Runtime.errors,0,'Learn errors'); assert(not learn.Runtime.faulted,'Learn faulted') end
    end
    for _,name in ipairs(order or {}) do H:load(name) end
    return H
end
return M
