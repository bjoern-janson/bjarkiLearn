-- Long-memory regression tests against the actual addon Lua modules.
-- Run from the repository root: lua5.1 tests/long_memory.lua
local ns={}
for _,name in ipairs({"Bootstrap.lua","Rules.lua","Network.lua","Core.lua"}) do
    assert(loadfile(name))("bjarkiLearn",ns)
end
local C=ns.Config
local checks=0
local function check(value,message)
    checks=checks+1
    if not value then error(message or ("assertion "..checks),2) end
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k,v in pairs(b) do if not equal(v,a[k]) then return false end end
    return true
end
local function example(number,family,sealed)
    local x,y,mask={}, {}, {}
    for i=1,C.featureCount do x[i]=0 end
    x[1]=number%2
    x[2]=number%3==0 and 1 or 0
    for i=1,6 do
        y[i]=family==i and 1 or 0
        mask[i]=true
    end
    return {x=x,y=y,mask=mask,regime="player",sealed=sealed,
        actor="Player-Synthetic",anchor=number,deadline=number+2,
        resolveAt=number+2.25,revision=1,coverage={true,true,true,true,true,true},
        lost={},predictions={neural={},linear={},frequency={}}}
end
local function archiveCount(core)
    local total=0
    for i=1,7 do total=total+#core.archive[i] end
    return total
end

check(C.schema==2,"new persisted schema")
check(C.maxArchive==128 and C.recentTrainLimit==128,"fixed budgets")

-- Correctable current-session rows must never enter immutable rehearsal.
local skip=ns.Core.New()
skip:_ArchiveEvicted(example(1,3,false))
check(archiveCount(skip)==0 and skip.stats.archiveSkippedUnsealed==1,
    "unsealed evidence was archived")

-- Seven independent reservoirs preserve even infrequent positive heads.
local a,b=ns.Core.New(),ns.Core.New()
local candidate=0
for family=1,7 do
    for i=1,200 do
        candidate=candidate+1
        local w=example(candidate,family,true)
        a:_ArchiveEvicted(w)
        b:_ArchiveEvicted(w)
    end
end
check(archiveCount(a)==128,"archive exceeds or fails to fill 128 entries")
check(equal(a.archive,b.archive),"archive sampling is nondeterministic")
check(equal(a.archiveSeen,b.archiveSeen),"reservoir counts differ")
check(a.archiveRng==b.archiveRng,"reservoir state differs")
for i=1,7 do
    local limit=i==7 and 32 or 16
    check(#a.archive[i]==limit,"wrong per-family memory cap")
    check(a.archiveSeen[i]==200,"wrong family observation count")
    for _,w in ipairs(a.archive[i]) do
        check(w.actor==nil and w.id==nil and w.regime=="player",
            "raw actor identity leaked to archive")
    end
end
local visible=ns.Core.New()
for i=1,C.maxExamples do visible.examples[i]=example(i,1,true) end
local nextWindow=example(1001,0,false)
visible:_Resolve(nextWindow)
check(visible.archiveSeen[1]==1 and #visible.archive[1]==1,
    "sealed row evicted from recent history was not archived")
local current=ns.Core.New()
for i=1,C.maxExamples do current.examples[i]=example(i,1,false) end
current:_Resolve(example(1001,0,false))
check(archiveCount(current)==0,"unsealed window survived as durable example")

-- Build a real serving model from both memories, without adding extra rows.
local core=ns.Core.New()
core.archive=ns.Copy(a.archive)
core.archiveSeen=ns.Copy(a.archiveSeen)
core.archiveRng=a.archiveRng
for i=1,192 do core.examples[i]=example(i+2000,7,true) end
core:_Dirty(false)
local ticks=0
while core.dirty do
    core:_Train()
    ticks=ticks+1
    check(ticks<=300,"bounded replay did not terminate")
end
check(core.model~=nil,"no serving model completed")
check(core.modelExamples==256,"model trained past the 256-row budget")
check(core.model:Valid(),"trained model has invalid numeric state")
local status=core:Status()
check(status.archiveExamples==128 and status.archiveSeen==1400,"wrong archive diagnostics")
local saved=core:Export()
check(saved.signature~=nil and saved.snapshot~=nil,"missing reproducible model checkpoint")
check(saved.snapshot.signature==saved.signature,"checkpoint/corpus mismatch")

-- Restore must preserve genuine long-term knowledge and copy state.
local restored=ns.Core.New()
local ok,reason=restored:Restore(saved)
check(ok,reason or "restore failed")
check(restored.snapshotRestored and not restored.dirty,"valid checkpoint not restored")
check(restored.model:Valid(),"restored model invalid")
check(restored.modelExamples==256,"restored model sample count changed")
check(equal(restored.archive,core.archive),"restored long-memory archive differs")
check(restored:Export().signature==saved.signature,"reexport digest changed")
local original=restored.archive[1][1].x[1]
saved.archive[1][1].x[1]=original==0 and 1 or 0
check(restored.archive[1][1].x[1]==original,"saved input aliased live state")

-- Bad authoritative history fails atomically; bad cache only forces rebuild.
local damaged=ns.Copy(core:Export())
damaged.archive[1][1].mask[1]=nil
local before=restored:Export().signature
local success=restored:Restore(damaged)
check(not success and restored:Export().signature==before,
    "malformed archive mutated a valid running model")
local cacheBad=ns.Copy(core:Export())
cacheBad.snapshot.model.hiddenWeights[1][1]=math.huge
local fallback=ns.Core.New()
check(fallback:Restore(cacheBad),"damaged optional snapshot rejected valid evidence")
check(not fallback.snapshotRestored and fallback.dirty and fallback.model==nil,
    "damaged checkpoint was trusted")
local signatureBad=ns.Copy(core:Export())
signatureBad.examples[1].x[1]=signatureBad.examples[1].x[1]==0 and 1 or 0
check(not fallback:Restore(signatureBad),"tampered corpus signature accepted")
check(fallback:Status().archiveExamples==128,"rejected restore changed archive")

-- Actual Core chronology: a late revision changes the active training label,
-- but only the subsequently sealed/deidentified outcome can enter rehearsal.
local live=ns.Core.New()
local actor="Player-Synthetic"
live:SetCoverage(true)
live:Context({actor=actor,at=10,role="self",class="DRUID",
    combat=true,health=1,power=1,bound=true})
live:Tick(10,true)
check(live.actors[actor].window~=nil,"combat failed to open a window")
check(live:Cast({actor=actor,id="cast-1",family=3,at=10.5,revision=1}),
    "cast evidence rejected")
live:Tick(12.4,false)
check(#live.examples==1 and live.examples[1].y[3]==1
    and live.examples[1].mask[3],"cast-positive label incorrect")
check(live:Cast({actor=actor,id="cast-1",family=3,at=10.5,
    revision=2,retracted=true}),"revision rejected")
check(live.examples[1].y[3]==0 and live.examples[1].mask[3],
    "corrected outcome not propagated to retained example")
local old=live.examples[1]
live:ResetSession(13)
check(old.sealed==true and old.actor==nil and old.id==nil,
    "session reset failed to seal/deidentify examples")
live:_ArchiveEvicted(old)
check(#live.archive[7]==1 and live.archive[7][1].y[3]==0,
    "long-term memory did not use corrected sealed outcome")
check(live.archive[7][1].actor==nil and live.archive[7][1].id==nil,
    "sealed memory restored a raw event identity")

-- A 0.1.x save cannot silently acquire the new training meaning.
local legacy=ns.Core.New()
check(not legacy:Restore({schema=1,compat="old",examples={}}),
    "old model semantics were silently imported")

io.write("long_memory.lua: PASS (",checks," checks, Lua ",_VERSION,")\n")
