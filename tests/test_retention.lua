-- Unknown-enemy retention regressions; run from repo root with Lua 5.1 or 5.4.
local ns = {}
for _,file in ipairs({"Bootstrap.lua","Rules.lua","Network.lua","Core.lua"}) do
    assert(loadfile(file))("bjarkiLearn",ns)
end
local SELF, OTHER = "Player-1-AABB", "Player-2-CCDD"
local failures, passed = {}, 0
local function check(label,condition)
    if not condition then error(label,2) end
end
local function equal(label,actual,expected)
    check(label..": expected "..tostring(expected)..", got "..tostring(actual),actual==expected)
end
local function case(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failures[#failures+1]=name..": "..tostring(why); print("FAIL "..failures[#failures]) end
end
local function context(c,actor,role,at,health)
    assert(c:Context({actor=actor,role=role,at=at,bound=true,combat=true,
        class=role=="self" and "DRUID" or "ROGUE",health=health or 1,power=.5}))
end
local function window(c,actor,role,at,id,health)
    context(c,actor,role,at,health); c:Tick(at,true)
    if id then
        context(c,actor,role,at+1,health) -- Observe time before delivering a cast.
        assert(c:Cast({actor=actor,id=id,family=2,at=at+1,revision=1}))
    end
    c:Tick(at+2.3,true)
end
local function unknown(row)
    if row.regime=="player" then return false end
    for i=1,6 do if row.mask[i] then return false end end
    return true
end
local function counts(c,u,p,s)
    local actual={0,0,0}
    for _,row in ipairs(c:Export().examples) do
        local index=row.regime=="player" and 3 or unknown(row) and 1 or 2
        actual[index]=actual[index]+1
    end
    equal("unknown rows",actual[1],u); equal("positive enemy rows",actual[2],p)
    equal("player rows",actual[3],s); check("global bound",#c.examples<=256)
end
local function anchors(c,first,last)
    equal("retained row count",#c.examples,last-first+1)
    for i=first,last do equal("retained insertion order",c.examples[i-first+1].anchor,i*3) end
end
local function same(a,b)
    if type(a)~="table" or type(b)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

case("initial unknown arrivals retain newest sixteen",function()
    local c=ns.Core.New()
    for i=1,30 do window(c,OTHER,"hostile",i*3) end
    counts(c,16,0,0); anchors(c,15,30)
    equal("retirement diagnostics",c:Status().unlabeledOtherRetired,14)
end)

case("retraction retains newest sixteen without changing anchors",function()
    local c=ns.Core.New()
    for i=1,16 do window(c,OTHER,"hostile",i*3) end
    window(c,OTHER,"hostile",51,"retract")
    local latest=c.examples[17]; local x=ns.Copy(latest.x)
    assert(c:Cast({actor=OTHER,id="retract",family=2,at=52,revision=2,retracted=true}))
    counts(c,16,0,0); anchors(c,2,17)
    check("corrected row preserved",c.examples[16]==latest and same(latest.x,x))
    equal("retirement diagnostics",c:Status().unlabeledOtherRetired,1)
    equal("enemy correction does not dirty corpus",c:Status().corpusRevision,0)
end)

case("reattribution away from enemy enforces cap",function()
    local c=ns.Core.New()
    for i=1,16 do window(c,OTHER,"hostile",i*3) end
    window(c,OTHER,"hostile",51,"move-actor")
    assert(c:Cast({actor="Player-3-EEFF",id="move-actor",family=2,at=52,revision=2}))
    counts(c,16,0,0); anchors(c,2,17)
end)

case("time correction outside horizon enforces cap",function()
    local c=ns.Core.New()
    for i=1,16 do window(c,OTHER,"hostile",i*3) end
    window(c,OTHER,"hostile",51,"move-time")
    assert(c:Cast({actor=OTHER,id="move-time",family=2,at=53.1,revision=2}))
    counts(c,16,0,0); anchors(c,2,17)
end)

case("one correction revises both rows before pruning",function()
    local c=ns.Core.New()
    window(c,OTHER,"hostile",3,"swap-time")
    for i=2,17 do window(c,OTHER,"hostile",i*3) end
    local first,last=c.examples[1],c.examples[17]
    assert(c:Cast({actor=OTHER,id="swap-time",family=2,at=52,revision=2}))
    counts(c,16,1,0); anchors(c,1,17)
    check("old row now unknown",unknown(first))
    check("new row now positive",last.y[2]==1 and last.mask[2]==true)
    equal("both rows revised",c:Status().labelRevisions,2)
    equal("no premature retirement",c:Status().unlabeledOtherRetired or 0,0)
end)

case("ordinary occurrence eviction retains sixteen unknown and 128 positive",function()
    local c=ns.Core.New()
    for i=1,256 do window(c,OTHER,"hostile",i*3,"ordinary-"..i) end
    counts(c,16,128,0); anchors(c,113,256)
    for i,row in ipairs(c.examples) do equal("unknown prefix",unknown(row),i<=16) end
    equal("occurrence bound",c:Status().occurrences,128)
    equal("occurrences retired",c:Status().occurrenceEvictions,128)
    equal("unknown retirement diagnostics",c:Status().unlabeledOtherRetired,112)
    equal("no player training",c:Status().corpusRevision,0)
end)

local function fullOccurrenceHistory()
    local c=ns.Core.New()
    window(c,OTHER,"hostile",3,"retiring-positive")
    for i=2,17 do window(c,OTHER,"hostile",i*3) end
    context(c,OTHER,"hostile",54)
    for i=1,127 do
        assert(c:Aura({recipient=OTHER,id="pressure-"..i,spellID=5277,at=54}))
    end
    equal("full occurrence registry",c:Status().occurrences,128)
    counts(c,16,1,0)
    return c
end

case("incoming cast restores positive before retirement pruning",function()
    local c=fullOccurrenceHistory(); local first=c.examples[1]
    -- Late evidence is newer than the evicted cast and inside the same window.
    assert(c:Cast({actor=OTHER,id="incoming-positive",family=2,at=4.5}))
    counts(c,16,1,0); anchors(c,1,17)
    check("original positive row retained",c.examples[1]==first and first.mask[2] and first.y[2]==1)
    equal("no interim unknown retirement",c:Status().unlabeledOtherRetired or 0,0)
end)

case("aura insertion prunes after retiring cast evidence",function()
    local c=fullOccurrenceHistory()
    assert(c:Aura({recipient=OTHER,id="incoming-aura",spellID=5277,at=54}))
    counts(c,16,0,0); anchors(c,2,17)
    equal("retirement diagnostics",c:Status().unlabeledOtherRetired,1)
end)

case("lost revision masks every matching row then prunes",function()
    local c=ns.Core.New(); c:SetCoverage(true)
    window(c,SELF,"self",3); c:Tick(6,false)
    check("real serving model",c.model~=nil)
    for i=1,18 do window(c,OTHER,"hostile",6+i*3,"lost-"..i) end
    local before=c:Status(); local player=c.examples[1]
    local ok,why=c:Cast({actor=OTHER,id="missing-history",family=2,at=61,revision=2})
    check("lost revision rejected",not ok and why=="revision_history_lost")
    counts(c,16,0,1)
    check("player row preserved",c.examples[1]==player)
    for i=2,17 do
        equal("newest masked rows retained",c.examples[i].anchor,(i+3)*3)
        check("all affected rows censored",c.examples[i].mask[2]==false)
    end
    equal("retirement diagnostics",c:Status().unlabeledOtherRetired,2)
    equal("conservative invalidation preserved",c:Status().invalidations,(before.invalidations or 0)+1)
    check("lost history still withdraws model",c.model==nil and c.candidate==nil)
end)

-- A compatible old save: 21 unknown enemies mixed with two positive enemies
-- and three player rows. Inputs and predictions originate from actual windows.
local function mixedSave()
    local source=ns.Core.New(); source:SetCoverage(true)
    for i=1,26 do
        local player=i==4 or i==10 or i==24
        window(source,player and SELF or OTHER,player and "self" or "hostile",
            i*3,not player and "saved-"..i or nil,i/32)
    end
    local saved=source:Export()
    for i,row in ipairs(saved.examples) do
        if row.regime=="other" and i~=8 and i~=20 then
            for family=1,6 do row.y[family]=0; row.mask[family]=false end
        end
    end
    return saved
end

case("Restore normalizes mixed save and preserves retained order",function()
    local saved=mixedSave(); local original=ns.Copy(saved)
    local c=ns.Core.New(); assert(c:Restore(saved))
    counts(c,16,2,3)
    local expected={saved.examples[4]}
    for i=7,26 do expected[#expected+1]=saved.examples[i] end
    check("retained order and row values",same(c:Export().examples,expected))
    check("input save remains unchanged",same(saved,original))
    for _,row in ipairs(c.examples) do check("restored rows remain sealed",row.sealed) end
    equal("restore retirement diagnostics",c:Status().unlabeledOtherRetired,5)
    local roundtrip=ns.Core.New(); assert(roundtrip:Restore(c:Export()))
    check("normalized save roundtrip",same(c:Export(),roundtrip:Export()))
end)

case("invalid oversized-unknown Restore is atomic",function()
    local c=ns.Core.New(); c:SetCoverage(true)
    window(c,SELF,"self",3); c:Tick(6,false)
    local before,model,examples,actors=c:Export(),c.model,c.examples,c.actors
    local status=c:Status(); local saved=mixedSave(); saved.examples[26].mask[6]="invalid"
    local ok,why=c:Restore(saved)
    check("invalid row rejected",not ok and why=="invalid_examples")
    check("corpus unchanged",same(before,c:Export()) and c.examples==examples)
    check("model and actors unchanged",c.model==model and c.actors==actors)
    check("status unchanged",same(status,c:Status()))
end)

case("new arrivals repair an already excessive legacy live corpus",function()
    local saved=mixedSave(); local c=ns.Core.New(); assert(c:Restore(saved))
    -- Deliberate sole private-state fixture: reproduce a validated, sealed
    -- corpus admitted by the old Restore, bypassing the repaired Restore cap.
    local legacy=ns.Copy(saved.examples)
    for _,row in ipairs(legacy) do row.sealed=true; row.revision=1 end
    c.examples=legacy
    for i=1,4 do
        window(c,OTHER,"hostile",90+i*3)
        counts(c,16,2,3)
        equal("newest arrival preserved",c.examples[#c.examples].anchor,90+i*3)
    end
    local expected={saved.examples[4],saved.examples[8],saved.examples[10]}
    for i=13,26 do expected[#expected+1]=saved.examples[i] end
    -- After nine old unknowns retire, retained saved rows are 4,8,10,13..26.
    for i,row in ipairs(expected) do check("legacy insertion order",same(c:Export().examples[i],row)) end
end)

case("enemy pruning preserves real serving model and in-progress candidate",function()
    local c=ns.Core.New(); c:SetCoverage(true)
    window(c,SELF,"self",3); window(c,SELF,"self",6)
    c:Tick(9,false); c:Tick(10,false)
    check("real model published",c.model~=nil)
    window(c,SELF,"self",12); c:Tick(15,false)
    local model,candidate=c.model,c.candidate; check("real candidate started",candidate~=nil)
    local revision,invalidations=c.corpusRevision,c:Status().invalidations or 0
    local players={c.examples[1],c.examples[2],c.examples[3]}
    for i=1,16 do window(c,OTHER,"hostile",15+i*3) end
    window(c,OTHER,"hostile",66,"enemy-only")
    assert(c:Cast({actor=OTHER,id="enemy-only",family=2,at=67,revision=2,retracted=true}))
    check("serving model and candidate preserved",c.model==model and c.candidate==candidate)
    equal("corpus revision unchanged",c.corpusRevision,revision)
    equal("no new invalidations",c:Status().invalidations or 0,invalidations)
    for i=1,3 do check("player row preserved",c.examples[i]==players[i]) end
    counts(c,16,0,3)
end)

case("full player corpus rejects enemy rows and retains global bound",function()
    local c=ns.Core.New(); c:SetCoverage(true)
    for i=1,256 do window(c,SELF,"self",i*3) end
    local before=c:Export()
    window(c,OTHER,"hostile",780); window(c,OTHER,"hostile",783,"capacity-positive")
    counts(c,0,0,256); check("all player rows unchanged",same(before,c:Export()))
    equal("unknown capacity drop",c:Status().unlabeledOtherDropped,1)
    equal("positive capacity drop",c:Status().otherCapacityDropped,1)
end)

print("Retention regressions: "..passed.." passed, "..#failures.." failed")
assert(#failures==0,table.concat(failures,"\n"))
