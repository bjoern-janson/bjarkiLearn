-- Focused 0.1.7-shadow source-executed regressions; run from repo root.
local ns = {}
for _, file in ipairs({"Bootstrap.lua","Rules.lua","Network.lua","Core.lua","Adapter.lua"}) do
    assert(loadfile(file))("bjarkiLearn",ns)
end

local SELF, OTHER = "Player-1-AABB", "Player-2-CCDD"
local activeAura = false
local auraExpiry = 9
UnitGUID = function(unit) return unit == "player" and SELF or unit == "target" and OTHER end
UnitIsPlayer = function(unit) return unit ~= "focus" end
UnitClassBase = function(unit) return unit == "player" and "DRUID" or "ROGUE" end
UnitCanAttack = function(_,unit) return unit == "target" end
UnitAffectingCombat = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitPowerType = function() return 0, "MANA" end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
C_UnitAuras = { GetUnitAuraBySpellID = function(unit,id)
    if activeAura and unit=="player" and id==22812 then
        return {spellId=22812,isHelpful=true,auraInstanceID=74,
            expirationTime=auraExpiry,duration=8}
    end
end }

local function context(core,actor,role,at)
    assert(core:Context({actor=actor,role=role,combat=true,
        class=role=="self" and "DRUID" or "ROGUE",
        health=1,power=.5,at=at,bound=true}))
end
local function window(core,actor,role,at)
    context(core,actor,role,at)
    core:Tick(at,true)
    core:Tick(at+2.3,true)
end
local function check(label,condition)
    if not condition then error(label,2) end
end

-- Native self aura supplies positive context without any Portraits self bus.
local nativeCore=ns.Core.New()
local adapter=ns.Adapter.New(nativeCore)
adapter:SetRegistered(true)
activeAura=true
adapter:Tick(1)
local present=nativeCore:GetContext(SELF,1).defensiveWitness
check("self aura provenance",present and present.source=="native-player-aura")
local input=ns.Rules.Features(nativeCore.actors[SELF],1,nativeCore:_Evidence(SELF,1))
check("self witness known",input[47]==1 and input[48]==1)
adapter:Tick(1.4) -- less than one second: no new scan
check("throttled three-spell scan",adapter.stats.selfAuraProbes==3)
adapter:Tick(2.2)
check("self aura refresh",nativeCore:GetContext(SELF,2.2).defensiveWitness.at==2.2)
activeAura=false
adapter:Tick(3.4)
local unseen=ns.Rules.Features(nativeCore.actors[SELF],10,nativeCore:_Evidence(SELF,10))
check("expired aura is not confirmed present",unseen[47]==0 and unseen[48]==0)

-- Enemy windows without a positive are not eligible to occupy player history.
local core=ns.Core.New()
core:SetCoverage(true)
for i=1,10 do
    local at=i*3
    context(core,SELF,"self",at)
    context(core,OTHER,"hostile",at)
    core:Tick(at,true); core:Tick(at+2.3,true)
end
check("bounded enemy unknowns retained",#core.examples==20)
check("unlabeled-retention counter",core.stats.unlabeledOtherRetained==10)
context(core,OTHER,"hostile",35)
core:Tick(35,true)
check("enemy positive accepted",core:Cast({
    actor=OTHER,id="enemy-stun",family=2,at=36,revision=1}))
core:Tick(37.3,true)
check("enemy positive retained",#core.examples==21 and core.examples[21].regime=="other")
check("enemy positive not training data",core:Status().trainingExamples==10)

-- A later correction can still reattribute a cast into a recent initially
-- empty enemy window, without granting unsupported negative labels.
local reattr=ns.Core.New()
reattr:SetCoverage(true)
context(reattr,SELF,"self",10)
context(reattr,OTHER,"hostile",10)
reattr:Tick(10,true)
check("initial attribution",reattr:Cast({actor=SELF,id="move-root",family=3,at=11,revision=1}))
reattr:Tick(12.3,true)
check("prior enemy window survives",#reattr.examples==2 and reattr.examples[2].actor==OTHER)
check("new attribution",reattr:Cast({actor=OTHER,id="move-root",family=3,at=11,revision=2}))
check("retrospective enemy positive",reattr.examples[2].y[3]==1 and reattr.examples[2].mask[3]==true)

-- Unknown enemy history stays bounded even without any player examples.
local unknown=ns.Core.New()
for i=1,30 do window(unknown,OTHER,"hostile",i*3) end
check("unknown enemy correction horizon bounded",#unknown.examples==16)
check("old unknowns retired",unknown.stats.unlabeledOtherRetired==14)

-- Even a positive enemy window cannot evict a full player-only corpus.
local cap=ns.Core.New()
cap:SetCoverage(true)
for i=1,256 do window(cap,SELF,"self",i*3) end
check("256 player examples",#cap.examples==256)
context(cap,OTHER,"hostile",1000)
cap:Tick(1000,true)
check("new enemy evidence",cap:Cast({
    actor=OTHER,id="extra-stun",family=2,at=1001,revision=1}))
cap:Tick(1002.3,true)
check("player examples protected",#cap.examples==256 and cap.examples[1].regime=="player")
check("enemy positive capacity dropped",cap.stats.otherCapacityDropped==1)

-- A clean corpus revision must not restart a candidate.
local training=ns.Core.New()
training:SetCoverage(true)
window(training,SELF,"self",3)
window(training,SELF,"self",6)
training:_Train()
local candidate=training.candidate
check("candidate started",candidate~=nil)
window(training,SELF,"self",20)
check("clean arrival preserves candidate",training.candidate==candidate)
for _=1,40 do
    if training.model then break end
    training:_Train()
end
check("lagged snapshot publishes",training.model~=nil
    and training.modelCorpusRevision<training.corpusRevision
    and training:Status().modelRefreshPending)
for _=1,40 do
    if not training.dirty then break end
    training:_Train()
end
check("fresh rebuild catches up",training.modelCorpusRevision==training.corpusRevision
    and training.dirty==false)

-- A correction must cancel a candidate even when its source row was evicted.
local corrected=ns.Core.New()
corrected:SetCoverage(true)
context(corrected,SELF,"self",1)
corrected:Tick(1,true)
check("first cast",corrected:Cast({actor=SELF,id="old-cast",family=2,at=2,revision=1}))
corrected:Tick(3.3,true)
window(corrected,SELF,"self",5)
window(corrected,SELF,"self",8)
corrected:_Train()
check("candidate with occurrence dependency",corrected.candidate~=nil)
for i=1,256 do window(corrected,SELF,"self",11+i*3) end
check("snapshot retained through row eviction",corrected.candidate~=nil
    and corrected.examples[1].anchor~=1)
check("retraction accepted",corrected:Cast({actor=SELF,id="old-cast",
    family=2,at=2,revision=2,retracted=true}))
check("evicted-row correction cancels candidate",corrected.candidate==nil)

-- A reset cannot publish a candidate carrying the prior session's IDs.
training:_Dirty(false)
training:_Train()
check("new candidate for reset",training.candidate~=nil)
training:ResetSession(2000)
check("world reset cancels candidate",training.candidate==nil)
print("0.1.7 focused Lua regressions PASS")
