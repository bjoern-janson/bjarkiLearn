local _, ns = ...
local R = { families = {"fear", "stun", "root", "silence", "interrupt", "defensive"} }
ns.Rules = R
local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local classIndex = {}
for i, class in ipairs(classes) do classIndex[class] = i end
R.Classes = classIndex

-- Reviewed cast vocabulary, frozen separately from CC's effect/DR tables.
-- Family labels denote ability use, never a successful effect on a recipient.
local casts = {}
local function add(family, ids)
    for _, id in ipairs(ids) do casts[id] = family end
end
add(1, {8122,8124,10888,10890,5484,17928,5246})
add(2, {853,5588,5589,10308,5211,6798,8983,408,8643,12809,20549})
add(3, {122,865,6131,10230,19306,20909,20910,1242634})
add(4, {15487})
add(5, {1766,1767,1768,1769,6552,6554,72,1671,1672,2139,19244,19647})
add(6, {22812,5277,26669})
R.SelfDefensive = {[22812]=true, [5277]=true, [26669]=true}
function R.Classify(spellID) return casts[spellID] end

-- These are possibility seeds, not exhaustive rules or event-rate priors.
-- Unknown item, racial, pet and changed-ruleset routes remain open.
local associations = {
    WARRIOR = {fear="candidate",stun="conditional",interrupt="candidate"},
    PALADIN = {stun="candidate"},
    HUNTER = {root="conditional"},
    ROGUE = {stun="candidate",interrupt="candidate",defensive="candidate"},
    PRIEST = {fear="candidate",silence="conditional"},
    SHAMAN = {},
    MAGE = {root="candidate",interrupt="candidate"},
    WARLOCK = {fear="candidate",interrupt="conditional"},
    DRUID = {stun="conditional",defensive="candidate"},
}
function R.Candidates(class)
    local known = associations[class] or {}
    local out = {}
    for _, family in ipairs(R.families) do
        local status = known[family] or "unknown"
        out[family] = {status=status, basis="forever-provisional-class-v1",
            reason=status=="conditional" and "build, form or controlled actor required"
                or status=="candidate" and "class association; availability unknown"
                or "no exhaustive exclusion established"}
    end
    return out
end

-- Stable schema: 10 class + 3 role + 6 value/known + 12 history
-- + 12 capability + 3 form + 2 positive witness = 48 inputs.
function R.Features(actor, now, evidence)
    evidence = evidence or actor
    local x = {}
    local function push(value) x[#x+1] = value end
    local class = classIndex[actor.class]
    for i=1,#classes do push(class==i and 1 or 0) end
    push(class and 1 or 0)
    for _,role in ipairs({"self","hostile","friendly"}) do push(actor.role==role and 1 or 0) end
    push(actor.combat==true and 1 or 0); push(actor.combat~=nil and 1 or 0)
    push(actor.health or 0); push(actor.health~=nil and 1 or 0)
    push(actor.power or 0); push(actor.power~=nil and 1 or 0)
    for i=1,6 do
        local at = evidence.history and evidence.history[i]
        if at and at>now then at=nil end
        push(at and math.max(0,1-math.max(0,now-at)/30) or 0)
        push(at and 1 or 0)
    end
    local known = associations[actor.class] or {}
    for _, family in ipairs(R.families) do
        push(known[family] and 1 or 0)
        push(known[family]=="conditional" and 1 or 0)
    end
    push(actor.form=="cat" and 1 or 0); push(actor.form=="bear" and 1 or 0)
    push(actor.form~=nil and 1 or 0)
    local witness = evidence.defensiveWitness
    local fresh = witness and now >= witness.at and now-witness.at <= 8
        and (not witness.expires or now < witness.expires)
    push(fresh and 1 or 0); push(fresh and 1 or 0)
    return x
end
