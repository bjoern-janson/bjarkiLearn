local _, ns = ...
local C, S, R = ns.Config, ns.Safe, ns.Rules
local Core = {}
Core.__index = Core
ns.Core = Core

local function number(v, minimum, maximum)
    v = S.Number(v)
    if v and v >= (minimum or 0) and v <= (maximum or 1000000000) then return v end
end
local function identifier(v)
    v = S.String(v)
    if v and #v > 0 and #v <= 160 then return v end
end
local function vector(value, size, kind)
    if not S.Table(value) then return nil end
    local out = {}
    for i=1,size do
        local v = S.Field(value,i)
        if kind=="mask" then
            v=S.Boolean(v); if v==nil then return nil end
        else
            v=number(v,0,1); if not v or (kind=="label" and v~=0 and v~=1) then return nil end
        end
        out[i]=v
    end
    if S.Field(value,size+1)~=nil then return nil end
    return out
end
local function any(mask)
    for i=1,6 do if mask[i] then return true end end
    return false
end
local function overlaps(w, event)
    return event and event.kind=="cast" and w.actor==event.actor
        and event.maxAt>w.anchor and event.minAt<=w.deadline
end
local function changed(a,b)
    for i=1,6 do if a[i]~=b[i] then return true end end
    return false
end
local function removeKey(order,key)
    for i=1,#order do if order[i]==key then table.remove(order,i); return end end
end

-- Fixed, stratified reservoir. Six positive-family buckets and one background
-- bucket prevent common negatives from replacing every rare positive.
local ARCHIVE_LIMITS = {16,16,16,16,16,16,32}
local RNG_MODULUS = 2147483647
local function archiveFamily(w)
    for i=1,6 do
        if w.mask[i] and w.y[i]==1 then return i end
    end
    return 7
end
local function emptyArchive()
    local buckets, seen = {}, {}
    for i=1,7 do buckets[i],seen[i]={},0 end
    return buckets,seen
end
local function denseCount(rows,limit)
    if not S.Table(rows) or getmetatable(rows)~=nil then return nil end
    local n=0
    for k in next,rows do
        local i=number(k,1,limit)
        if not i or i~=math.floor(i) then return nil end
        n=n+1
    end
    for i=1,n do if S.Field(rows,i)==nil then return nil end end
    return n
end
local function corpusSignature(examples,archive)
    -- Stable, non-cryptographic corruption guard for an optional model cache.
    -- Every trained feature and label participates; no private identity does.
    local hash=104729
    local function add(value)
        local token=type(value)=="number" and string.format("%.17g",value)
            or type(value)=="boolean" and (value and "T" or "F") or tostring(value)
        for i=1,#token do hash=(hash*33+token:byte(i))%RNG_MODULUS end
        hash=(hash*33+124)%RNG_MODULUS
    end
    local function row(w)
        add(w.regime)
        for i=1,C.featureCount do add(w.x[i]) end
        for i=1,6 do add(w.y[i]);add(w.mask[i]) end
    end
    for i=1,7 do
        add(i)
        for _,w in ipairs(archive[i]) do row(w) end
    end
    for _,w in ipairs(examples) do row(w) end
    return hash
end

function Core.New()
    local archive,archiveSeen=emptyArchive()
    return setmetatable({actors={},actorOrder={},occurrences={},occurrenceOrder={},examples={},
        archive=archive,archiveSeen=archiveSeen,archiveRng=C.seed,
        stats={},gapReasons={},coverage=false,now=0,nextWindow=0,corpusRevision=0,
        modelVersion=0,modelDependencies={},dirty=false,inferenceCursor=0,session=1,evidenceFloor=-1,openAfter=0,
        evidenceTime=0,nextCastAt=nil},Core)
end
-- A completed model is a frozen serving snapshot, separate from replay history.
-- Only evidence corrections (not routine forgetting) withdraw that snapshot.
function Core:_WithdrawModel()
    self.model=nil; self.modelDependencies={}
    self.modelCorpusRevision=nil; self.modelExamples=nil
    for _,actor in pairs(self.actors) do actor.forecast=nil end
end
function Core:_SnapshotStatus(out)
    out.corpusRevision=self.corpusRevision
    out.modelCorpusRevision=self.modelCorpusRevision
    out.modelExamples=self.modelExamples
    out.modelRefreshPending=self.model~=nil and self.modelCorpusRevision~=self.corpusRevision
end
function Core:_Dirty(invalidate)
    self.corpusRevision=self.corpusRevision+1
    self.dirty=true; self.candidate=nil
    if invalidate then
        self:_WithdrawModel()
        ns.Bump(self.stats,"invalidations")
    end
end
function Core:SetCoverage(enabled)
    self.coverage=enabled==true
    if not self.coverage then self:Gap("coverage_unavailable") end
end
function Core:Gap(reason, actorID)
    reason=identifier(reason) or "unknown"
    ns.Bump(self.gapReasons,reason)
    for id,actor in pairs(self.actors) do
        if not actorID or id==actorID then
            if actor.window then
                for i=1,6 do actor.window.coverage[i]=false end
            end
        end
    end
end

function Core:Context(raw)
    if not S.Table(raw) then return nil,"invalid_context" end
    local id,at=identifier(raw.actor),number(raw.at)
    if not id or not at then return nil,"invalid_context" end
    local a=self.actors[id]
    if a and at<a.at then return nil,"stale_context" end
    self:_AdvanceEvidence(at)
    if not a then
        if #self.actorOrder>=C.maxActors then
            local oldest=self.actorOrder[1]
            for _,key in ipairs(self.actorOrder) do
                if self.actors[key].at<self.actors[oldest].at then oldest=key end
            end
            local retired=self.actors[oldest]
            if retired.window then
                -- A recreated actor must not open a second overlapping window.
                -- A short global pause avoids retaining an unbounded ID map.
                self.openAfter=math.max(self.openAfter,retired.window.resolveAt)
                ns.Bump(self.stats,"actorCapacityPauses")
                for i=1,6 do retired.window.coverage[i]=false end
                self:_Resolve(retired.window)
            end
            self.actors[oldest]=nil; removeKey(self.actorOrder,oldest)
            ns.Bump(self.stats,"actorEvictions")
        end
        a={actor=id,revision=0}
        self.actors[id]=a; self.actorOrder[#self.actorOrder+1]=id
        self:_InvalidateActorEvidence(id)
    end
    if S.Boolean(raw.bound)==false then
        -- A missing unit token ends visibility, not the identity's known class.
        if a.bound~=false then a.revision=a.revision+1 end
        a.bound=false; a.at=at; a.forecast=nil
        self:Gap("binding_lost",id)
        return a
    end
    local role=S.String(raw.role)
    if role~="self" and role~="hostile" and role~="friendly" then role="unknown" end
    local class=S.String(raw.class)
    if not R.Classes[class] then class=nil end
    local form=S.String(raw.form)
    if form~="cat" and form~="bear" then form=nil end
    local values={class=class,role=role,regime=role=="self" and "player" or "other",
        combat=S.Boolean(raw.combat),health=number(raw.health,0,1),power=number(raw.power,0,1),
        form=form,bound=S.Boolean(raw.bound)~=false}
    local revise=false
    for _,key in ipairs({"class","role","regime","combat","health","power","form","bound"}) do
        if a[key]~=values[key] then revise=true end
    end
    if a.regime and a.regime~=values.regime then self:Gap("regime_changed",id) end
    if values.regime=="player" and values.combat==nil then self:Gap("combat_unknown",id) end
    if not values.bound then self:Gap("binding_lost",id) end
    for _,key in ipairs({"class","role","regime","combat","health","power","form","bound"}) do a[key]=values[key] end
    if revise then a.revision=a.revision+1; a.forecast=nil end
    a.at=at
    return a
end

-- Project the bounded registry at the caller's time. A future latest record
-- must not hide an earlier retained witness, or mutate an older query's view.
function Core:_Evidence(id,now)
    local out={history={}}
    for _,key in ipairs(self.occurrenceOrder) do
        local e=self.occurrences[key]
        local cast=e.kind=="cast" and not e.retracted and e.minAt==e.maxAt
        local aura=e.kind=="aura" and R.SelfDefensive[e.spellID]
        if e.actor==id and (cast or aura) then
            if now and e.at>now then
                out.nextAt=math.min(out.nextAt or e.at,e.at)
            elseif cast then
                if not out.history[e.family] or out.history[e.family]<e.at then out.history[e.family]=e.at end
            elseif not out.defensiveWitness or out.defensiveWitness.at<=e.at then
                out.defensiveWitness={at=e.at,expires=e.expires,spellID=e.spellID,
                    revision=e.revision,kind="observed",source="bjarkiPortraits"}
            end
        end
    end
    return out
end
-- Evidence lives in the occurrence registry; actor writes only invalidate
-- cached forecasts. GetContext and feature extraction project it when needed.
function Core:_InvalidateActorEvidence(id)
    local a=self.actors[id]
    if not a then return end
    a.revision=a.revision+1; a.forecast=nil
end
-- Context and Tick are clock observations; queries and cast timestamps are not.
-- One due-time scalar avoids another queue or identity registry. Sweep only when
-- a retained future cast can mature, including rows whose actor was retired.
function Core:_AdvanceEvidence(now)
    if now<=self.evidenceTime then return end
    local previous=self.evidenceTime
    self.evidenceTime=now
    if self.nextCastAt and self.nextCastAt<=now then
        self.nextCastAt=nil
        for _,key in ipairs(self.occurrenceOrder) do
            local e=self.occurrences[key]
            if e.kind=="cast" and not e.retracted and e.maxAt>now then
                self.nextCastAt=math.min(self.nextCastAt or e.maxAt,e.maxAt)
            end
        end
        self:_ReconcileTimeAdvance(previous)
    end
end

function Core:_Labels(w)
    local y,mask,lead={},{},{}
    for i=1,6 do y[i]=0; mask[i]=w.coverage[i] and not w.lost[i] end
    for _,key in ipairs(self.occurrenceOrder) do
        local e=self.occurrences[key]
        if overlaps(w,e) and not e.retracted then
            local i=e.family
            if e.minAt>w.anchor and e.maxAt<=w.deadline and e.maxAt<=self.evidenceTime then
                y[i]=1; mask[i]=true
                local delta=e.minAt-w.anchor
                if not lead[i] or delta<lead[i] then lead[i]=delta end
            elseif y[i]~=1 then mask[i]=false end
        end
    end
    return y,mask,lead
end
function Core:_AffectsModel(old,new)
    if not self.model then return false end
    if old and new and old.actor==new.actor and old.family==new.family
        and old.at==new.at and old.minAt==new.minAt and old.maxAt==new.maxAt
        and old.retracted==new.retracted then return false end
    -- These descriptors outlive evicted replay rows, but never the serving
    -- generation or session. Check both sides of actor/time reattribution.
    for _,w in ipairs(self.modelDependencies) do
        if overlaps(w,old) or overlaps(w,new) then return true end
    end
    return false
end
-- All triggers use the same outcome update. Lead-only refinements do not
-- change training labels, so they leave the row revision and corpus intact.
function Core:_ReviseWindow(w)
    local y,mask,lead=self:_Labels(w)
    if changed(y,w.y) or changed(mask,w.mask) then
        w.y,w.mask,w.lead=y,mask,lead
        w.revision=(w.revision or 1)+1
        ns.Bump(self.stats,"labelRevisions")
        return w.regime=="player"
    end
    w.lead=lead
    return false
end
function Core:_ReviseAffectedWindows(old,new)
    local revised=false
    for _,w in ipairs(self.examples) do
        if not w.sealed and (overlaps(w,old) or overlaps(w,new)) then
            if self:_ReviseWindow(w) then revised=true end
        end
    end
    return revised
end
function Core:_ReconcileEvidenceChange(old,new)
    local affects=self:_AffectsModel(old,new)
    local revised=self:_ReviseAffectedWindows(old,new)
    if revised or affects then self:_Dirty(true) end
end
function Core:_ReconcileHistoryRetirement(old)
    -- Losing replay evidence rebuilds the candidate, but a completed serving
    -- snapshot remains valid until contradictory evidence reaches its guards.
    if self:_ReviseAffectedWindows(old,nil) then self:_Dirty(false) end
end
function Core:_ReconcileTimeAdvance(since)
    local affects=false
    if self.model then
        for _,key in ipairs(self.occurrenceOrder) do
            local e=self.occurrences[key]
            if e.kind=="cast" and not e.retracted and e.maxAt>since and e.maxAt<=self.evidenceTime
                and self:_AffectsModel(nil,e) then affects=true; break end
        end
    end
    local revised=false
    for _,w in ipairs(self.examples) do
        if not w.sealed then
            if self:_ReviseWindow(w) then revised=true end
        end
    end
    if revised or affects then self:_Dirty(true) end
end
function Core:_EvictOccurrence()
    local key=table.remove(self.occurrenceOrder,1)
    local old=self.occurrences[key]
    self.occurrences[key]=nil
    ns.Bump(self.stats,"occurrenceEvictions")
    if old.kind=="cast" then
        self.evidenceFloor=math.max(self.evidenceFloor,old.latestEver or old.maxAt)
        local function lose(w)
            if not w.sealed and overlaps(w,old) then w.lost[old.family]=true end
        end
        for _,a in pairs(self.actors) do if a.window then lose(a.window) end end
        for _,w in ipairs(self.examples) do lose(w) end
        self:_ReconcileHistoryRetirement(old)
    end
    self:_InvalidateActorEvidence(old.actor)
end
function Core:_Insert(key,record)
    if not self.occurrences[key] then
        if #self.occurrenceOrder>=C.maxOccurrences then self:_EvictOccurrence() end
        self.occurrenceOrder[#self.occurrenceOrder+1]=key
    end
    self.occurrences[key]=record
end

function Core:Cast(raw)
    if not S.Table(raw) then return false,"invalid_cast" end
    local id,actor=identifier(raw.id),identifier(raw.actor)
    local at,family=number(raw.at),number(raw.family,1,6)
    local revision=raw.revision==nil and 1 or number(raw.revision,1,2147483647)
    if not id or not actor or not at or not family or family~=math.floor(family)
        or not revision or revision~=math.floor(revision) then return false,"invalid_cast" end
    local lo=raw.minAt==nil and at or number(raw.minAt)
    local hi=raw.maxAt==nil and at or number(raw.maxAt)
    if not lo or not hi or lo>at or hi<at then return false,"invalid_interval" end
    local key="cast:"..id
    local old=self.occurrences[key]
    if old and revision<=old.revision then
        ns.Bump(self.stats,"duplicateCasts"); return false,"duplicate"
    end
    if not old and revision>1 then
        -- The old dependency cannot be reconstructed. Conservatively censor
        -- this actor/family's retained outcomes and retire the adaptive model.
        for _,w in ipairs(self.examples) do
            if not w.sealed and w.actor==actor then w.lost[family]=true; w.mask[family]=false end
        end
        local a=self.actors[actor]
        if a and a.window then a.window.lost[family]=true end
        self:_Dirty(true); ns.Bump(self.stats,"lostRevisions")
        return false,"revision_history_lost"
    end
    local e={kind="cast",id=id,actor=actor,at=at,minAt=lo,maxAt=hi,family=family,
        revision=revision,retracted=raw.retracted==true,source="native-cast",
        latestEver=math.max(hi,old and (old.latestEver or old.maxAt) or hi)}
    if not old and lo<=self.evidenceFloor then
        -- Forgotten identities cannot regain authority by arriving as revision 1.
        -- This time floor also remembers timestamps superseded by a backdate.
        for _,w in ipairs(self.examples) do
            if not w.sealed and overlaps(w,e) then w.lost[family]=true end
        end
        for _,a in pairs(self.actors) do
            if a.window and overlaps(a.window,e) then a.window.lost[family]=true end
        end
        self:_ReconcileEvidenceChange(e,nil)
        ns.Bump(self.stats,"staleCasts")
        return false,"outside_retained_history"
    end
    self:_Insert(key,e)
    if not e.retracted and e.maxAt>self.evidenceTime then
        self.nextCastAt=math.min(self.nextCastAt or e.maxAt,e.maxAt)
    end
    if old then ns.Bump(self.stats,"occurrenceRevisions") else ns.Bump(self.stats,"casts") end
    self:_ReconcileEvidenceChange(old,e)
    self:_InvalidateActorEvidence(actor)
    if old and old.actor~=actor then self:_InvalidateActorEvidence(old.actor) end
    return true
end

function Core:Aura(raw)
    if not S.Table(raw) then return false,"invalid_aura" end
    local id,actor=identifier(raw.id),identifier(raw.recipient)
    local at,spell=number(raw.at),number(raw.spellID,1,9999999)
    if not id or not actor or not at or not spell or spell~=math.floor(spell) then return false,"invalid_aura" end
    local key="aura:"..actor..":"..id
    local old=self.occurrences[key]
    if old and at<old.at then return false,"stale_aura" end
    local expiry=number(raw.expires)
    local freshApplication=old and raw.newApplication==true and at>old.at
    if not expiry and old and not freshApplication then expiry=old.expires end
    if old and old.expires==expiry and old.at==at then return false,"duplicate" end
    local e={kind="aura",id=id,actor=actor,at=at,spellID=spell,
        expires=expiry,revision=old and old.revision+1 or 1,
        firstSighting=not old,source="bjarkiPortraits"}
    self:_Insert(key,e); self:_InvalidateActorEvidence(actor)
    ns.Bump(self.stats,old and "auraRevisions" or "auraWitnesses")
    return true
end

function Core:_Predictions(actor,x)
    local predictions={neural={},linear={},frequency={}}
    if not self.model or actor.regime~="player" then return predictions end
    local raw=self.model:Predict(x)
    if not raw then self:_Dirty(true); ns.Bump(self.stats,"numericFailures"); return predictions end
    for i=1,6 do
        if self.model.positives[i]>=2 and self.model.totals[i]-self.model.positives[i]>=8 then
            for _,name in ipairs({"neural","linear","frequency"}) do predictions[name][i]=raw[name][i] end
        end
    end
    return predictions
end
function Core:_MakeForecast(a,now,x,predictions,nextAt)
    local f={actor=a.actor,kind="forecast",mode="shadow",usable=false,at=now,
        expires=math.min(now+C.horizon,nextAt or now+C.horizon),horizon=C.horizon,contextRevision=a.revision,
        modelVersion=self.modelVersion,regime=a.regime,target=C.target,outputs={}}
    local candidates=R.Candidates(a.class)
    for i,name in ipairs(R.families) do
        local score=predictions.neural[i]
        local reason=a.regime~="player" and "unsupported_enemy_coverage"
            or not self.model and (self.dirty and "rebuilding" or "cold_start")
            or not score and "insufficient_positive_and_negative_support" or "shadow_only"
        f.outputs[i]={family=name,score=score,linear=predictions.linear[i],frequency=predictions.frequency[i],
            status=score and "shadow" or "withheld",usable=false,reason=reason,
            candidate=candidates[name],calibrated=false}
    end
    a.forecast=f
    return f
end
function Core:_Open(a,now)
    local evidence=self:_Evidence(a.actor,now)
    local x=R.Features(a,now,evidence)
    local predictions=self:_Predictions(a,x)
    self.nextWindow=self.nextWindow+1
    local w={id=self.nextWindow,actor=a.actor,anchor=now,deadline=now+C.horizon,
        resolveAt=now+C.horizon+C.grace,regime=a.regime,x=x,predictions=predictions,
        contextRevision=a.revision,modelVersion=self.modelVersion,coverage={},lost={},revision=1}
    for i=1,6 do w.coverage[i]=self.coverage and a.role=="self" end
    a.window=w
    self:_MakeForecast(a,now,x,predictions,evidence.nextAt)
    ns.Bump(self.stats,"openedWindows")
end
-- Only examples sealed by a prior session boundary may enter long-term
-- rehearsal. An active-session eviction might still receive a correction:
-- dropping it is safer than permanently learning a label we cannot revise.
function Core:_ArchiveEvicted(w)
    if w.regime~="player" or not any(w.mask) then return end
    if not w.sealed then
        ns.Bump(self.stats,"archiveSkippedUnsealed")
        return
    end
    local family=archiveFamily(w)
    local bucket=self.archive[family]
    ns.Bump(self.archiveSeen,family)
    self.archiveRng=(self.archiveRng*16807)%RNG_MODULUS
    local count=self.archiveSeen[family]
    local limit=ARCHIVE_LIMITS[family]
    local index=math.floor(self.archiveRng/RNG_MODULUS*count)+1
    if #bucket<limit or index<=limit then
        local row={x=ns.Copy(w.x),y=ns.Copy(w.y),mask=ns.Copy(w.mask),regime="player"}
        if #bucket<limit then bucket[#bucket+1]=row
        else bucket[index]=row end
        ns.Bump(self.stats,"archiveSelections")
    end
    ns.Bump(self.stats,"archiveCandidates")
end

function Core:_Resolve(w)
    w.y,w.mask,w.lead=self:_Labels(w)
    if #self.examples>=C.maxExamples then
        local retired=table.remove(self.examples,1)
        self:_ArchiveEvicted(retired)
        ns.Bump(self.stats,"exampleEvictions")
        -- A frozen serving model survives normal history retirement; its
        -- existing transient correction guards still protect recent lessons.
        self:_Dirty(false)
    end
    self.examples[#self.examples+1]=w
    ns.Bump(self.stats,"resolvedWindows")
    if w.regime=="player" and any(w.mask) then self:_Dirty(false) end
end

function Core:_Train()
    if not self.dirty then return end
    if not self.candidate then
        local data={}
        -- Rehearse immutable earlier sessions first, then up to 128 current
        -- examples. Training remains bounded to 256 rows and fully rebuildable.
        for family=1,7 do
            for _,w in ipairs(self.archive[family]) do
                data[#data+1]={x=ns.Copy(w.x),y=ns.Copy(w.y),mask=ns.Copy(w.mask)}
            end
        end
        local recent={}
        for _,w in ipairs(self.examples) do
            if w.regime=="player" and any(w.mask) then
                recent[#recent+1]=w
            end
        end
        local first=math.max(1,#recent-C.recentTrainLimit+1)
        for n=first,#recent do
            local w=recent[n]
            data[#data+1]={x=ns.Copy(w.x),y=ns.Copy(w.y),mask=ns.Copy(w.mask)}
        end
        if #data==0 then self:_WithdrawModel(); self.dirty=false; return end
        local model=ns.Models.New(C.featureCount,C.hiddenCount,C.outputCount,C.seed)
        if not model then self.dirty=false; ns.Bump(self.stats,"numericFailures"); return end
        self.candidate={model=model,data=data,index=1,epoch=1,revision=self.corpusRevision}
    end
    local job=self.candidate
    local started=S.Number(S.Call(debugprofilestop))
    for _=1,C.stepsPerTick do
        local row=job.data[job.index]
        local ok=job.model:Learn(row.x,row.y,row.mask,job.epoch==1)
        if not ok then
            self.candidate=nil; self.dirty=false
            ns.Bump(self.stats,"numericFailures"); return
        end
        ns.Bump(self.stats,"trainingSteps")
        job.index=job.index+1
        if job.index>#job.data then
            job.index=1; job.epoch=job.epoch+1
            if job.epoch>C.epochs then
                if job.model:Valid() and job.revision==self.corpusRevision then
                    self.model=job.model; self.modelVersion=self.modelVersion+1
                    self.modelCorpusRevision=job.revision; self.modelExamples=#job.data
                    -- Same corpus revision guarantees these are the replay's
                    -- windows. Reuse one bounded registry; the candidate holds
                    -- no additional dependency copy. Sealed rows have no raw IDs.
                    for i=#self.modelDependencies,1,-1 do self.modelDependencies[i]=nil end
                    for _,w in ipairs(self.examples) do
                        if not w.sealed and w.regime=="player" and any(w.mask) then
                            self.modelDependencies[#self.modelDependencies+1]={
                                actor=w.actor,anchor=w.anchor,deadline=w.deadline}
                        end
                    end
                    self.dirty=false; ns.Bump(self.stats,"rebuilds")
                    for _,a in pairs(self.actors) do a.forecast=nil end
                end
                self.candidate=nil
                break
            end
        end
        local elapsed=started and S.Number(S.Call(debugprofilestop))
        if elapsed and elapsed-started>=1.5 then break end
    end
end

function Core:Tick(now,inCombat)
    now=number(now)
    if not now then return end
    if now<self.now then self:ResetSession(now) end
    self.now=now
    self:_AdvanceEvidence(now)
    for _,id in ipairs(self.actorOrder) do
        local a=self.actors[id]
        if a.window and now>=a.window.resolveAt then self:_Resolve(a.window); a.window=nil end
        if inCombat==true and now>=self.openAfter and (a.role~="self" or a.combat==true)
            and a.bound and now>=a.at and now-a.at<=C.contextTTL and not a.window then
            self:_Open(a,now)
        end
    end
    -- One shared cached projection per actor; no independent consumer inference.
    -- The native adapter tracks only three units. Extra bus actors are bounded.
    local count=#self.actorOrder
    for _=1,math.min(4,count) do
        self.inferenceCursor=self.inferenceCursor%count+1
        local a=self.actors[self.actorOrder[self.inferenceCursor]]
        if a.bound and now>=a.at and now-a.at<=C.contextTTL
            and (not a.forecast or a.forecast.expires<=now or a.forecast.contextRevision~=a.revision) then
            local evidence=self:_Evidence(a.actor,now)
            local x=R.Features(a,now,evidence)
            self:_MakeForecast(a,now,x,self:_Predictions(a,x),evidence.nextAt)
        end
    end
    if inCombat==false then self:_Train() end
end

function Core:GetContext(id,now)
    local a=self.actors[id]
    if not a then return nil end
    now=number(now)
    local evidence=self:_Evidence(id,now or -1)
    local out={actor=id,class=a.class,role=a.role,regime=a.regime,revision=a.revision,
        observedAt=a.at,form=a.form,combat=a.combat,health=a.health,power=a.power,
        candidates=R.Candidates(a.class),history=evidence.history,
        defensiveWitness=evidence.defensiveWitness,bound=a.bound}
    out.fresh=number(now)~=nil and now>=a.at and now-a.at<=C.contextTTL and a.bound
    return out
end
function Core:Forecast(id,now)
    local a=self.actors[id]
    if not a then return {usable=false,mode="shadow",reason="unknown_actor",outputs={}} end
    local f=ns.Copy(a.forecast)
    if not f then
        f={actor=id,usable=false,mode="shadow",outputs={}}
        for i,family in ipairs(R.families) do f.outputs[i]={family=family,usable=false,status="withheld",reason="not_computed"} end
    end
    -- Refresh metadata even when the numeric projection is cached.
    self:_SnapshotStatus(f)
    local why
    if not number(now) or now<a.at or not a.bound or now-a.at>C.contextTTL then why="stale_context"
    elseif f.at and now<f.at then why="future_projection"
    elseif f.expires and now>=f.expires then why="expired"
    elseif f.contextRevision and f.contextRevision~=a.revision then why="context_revised" end
    if why then
        f.reason=why
        for _,out in ipairs(f.outputs) do
            out.score=nil; out.linear=nil; out.frequency=nil; out.status="withheld"; out.reason=why
        end
    end
    return f
end

function Core:Status()
    local out=ns.Copy(self.stats)
    out.mode="shadow"; out.version=C.version; out.actors=#self.actorOrder
    out.occurrences=#self.occurrenceOrder; out.examples=#self.examples
    out.modelVersion=self.modelVersion; out.training=self.candidate~=nil; out.dirty=self.dirty
    out.archiveExamples=0;out.archiveSeen=0;out.archiveByFamily={}
    for i=1,7 do
        local count=#self.archive[i]
        out.archiveByFamily[i]=count
        out.archiveExamples=out.archiveExamples+count
        out.archiveSeen=out.archiveSeen+self.archiveSeen[i]
    end
    out.snapshotRestored=self.snapshotRestored==true
    self:_SnapshotStatus(out); out.modelDependencyCount=#self.modelDependencies
    out.evidenceFloor=self.evidenceFloor; out.openAfter=self.openAfter
    out.trainingSteps=out.trainingSteps or 0; out.trainingExamples=0; out.pending=0
    out.gapReasons=ns.Copy(self.gapReasons); out.families={}
    for _,a in pairs(self.actors) do if a.window then out.pending=out.pending+1 end end
    for i,family in ipairs(R.families) do
        out.families[i]={family=family,positive=0,negative=0,censored=0,otherPositive=0,
            scored=0,neuralLoss=0,linearLoss=0,frequencyLoss=0,winsVsLinear=0,lossesVsLinear=0,tiesVsLinear=0}
    end
    for _,w in ipairs(self.examples) do
        if w.regime=="player" and any(w.mask) then out.trainingExamples=out.trainingExamples+1 end
        for i=1,6 do
            local f=out.families[i]
            if w.regime~="player" then
                if w.mask[i] and w.y[i]==1 then f.otherPositive=f.otherPositive+1 end
            elseif not w.mask[i] then f.censored=f.censored+1
            else
                if w.y[i]==1 then f.positive=f.positive+1 else f.negative=f.negative+1 end
                local p=w.predictions
                if p and p.neural[i] and p.linear[i] and p.frequency[i] then
                    local n,l,b=(p.neural[i]-w.y[i])^2,(p.linear[i]-w.y[i])^2,(p.frequency[i]-w.y[i])^2
                    f.scored=f.scored+1; f.neuralLoss=f.neuralLoss+n; f.linearLoss=f.linearLoss+l; f.frequencyLoss=f.frequencyLoss+b
                    if math.abs(n-l)<1e-12 then f.tiesVsLinear=f.tiesVsLinear+1
                    elseif n<l then f.winsVsLinear=f.winsVsLinear+1 else f.lossesVsLinear=f.lossesVsLinear+1 end
                end
            end
        end
    end
    for _,f in ipairs(out.families) do
        if f.scored>0 then
            f.neuralLoss=f.neuralLoss/f.scored; f.linearLoss=f.linearLoss/f.scored; f.frequencyLoss=f.frequencyLoss/f.scored
        else f.neuralLoss=nil; f.linearLoss=nil; f.frequencyLoss=nil end
    end
    return out
end

function Core:ResetSession(now)
    now=number(now) or 0
    self:_AdvanceEvidence(now)
    -- Match normal Tick order so hash iteration cannot change FIFO retention.
    for _,id in ipairs(self.actorOrder) do
        local a=self.actors[id]
        if a.window then
            for i=1,6 do a.window.coverage[i]=false end
            self:_Resolve(a.window)
        end
    end
    for _,w in ipairs(self.examples) do
        w.sealed=true; w.actor=nil; w.id=nil; w.coverage=nil; w.lost=nil
    end
    self.actors={}; self.actorOrder={}; self.occurrences={}; self.occurrenceOrder={}
    self.modelDependencies={}
    self.now=now; self.evidenceTime=now; self.nextCastAt=nil; self.inferenceCursor=0; self.session=self.session+1
    self.evidenceFloor=-1; self.openAfter=self.now
    ns.Bump(self.stats,"sessionResets")
end
function Core:Export()
    local out={schema=C.schema,compat=C.compat,examples={},
        archive=ns.Copy(self.archive),archiveSeen=ns.Copy(self.archiveSeen),archiveRng=self.archiveRng}
    for _,w in ipairs(self.examples) do
        out.examples[#out.examples+1]={x=ns.Copy(w.x),y=ns.Copy(w.y),mask=ns.Copy(w.mask),
            regime=w.regime,predictions=ns.Copy(w.predictions)}
    end
    out.signature=corpusSignature(out.examples,out.archive)
    -- Optional fast serving cache, never the authority for training. A model
    -- differing from current replay history is intentionally not serialized.
    if self.model and not self.dirty and self.modelCorpusRevision==self.corpusRevision then
        local ok=self.model:Valid()
        if ok then out.snapshot={signature=out.signature,model=ns.Copy(self.model),
            examples=self.modelExamples} end
    end
    return out
end
function Core:Restore(saved)
    if not S.Table(saved) or S.Field(saved,"schema")~=C.schema or S.Field(saved,"compat")~=C.compat then
        ns.Bump(self.stats,"incompatibleSaves"); return false,"incompatible"
    end
    local rows=S.Table(S.Field(saved,"examples"))
    if not rows then return false,"invalid_examples" end
    -- Validate the whole plain array before replacing any live state. A hole
    -- must not turn a malformed save into a successful prefix-only restore.
    local meta=getmetatable(rows)
    if not S.Readable(meta) or meta~=nil then return false,"invalid_examples" end
    local count=0
    for key in next,rows do
        local index=number(key,1,C.maxExamples)
        if not index or index~=math.floor(index) then return false,"invalid_examples" end
        count=count+1
    end
    local restored={}
    for n=1,count do
        local raw=S.Table(S.Field(rows,n))
        if not raw then return false,"invalid_examples" end
        local x=vector(S.Field(raw,"x"),C.featureCount,"input")
        local y=vector(S.Field(raw,"y"),6,"label")
        local mask=vector(S.Field(raw,"mask"),6,"mask")
        local regime=S.String(S.Field(raw,"regime"))
        if not x or not y or not mask or (regime~="player" and regime~="other") then return false,"invalid_examples" end
        -- Prequential predictions are optional diagnostics, never labels.
        local predictions={neural={},linear={},frequency={}}
        local source=S.Table(S.Field(raw,"predictions"))
        if source then
            for _,name in ipairs({"neural","linear","frequency"}) do
                local fields=S.Table(S.Field(source,name))
                if fields then for i=1,6 do predictions[name][i]=number(S.Field(fields,i),0,1) end end
            end
        end
        restored[#restored+1]={x=x,y=y,mask=mask,regime=regime,predictions=predictions,sealed=true,revision=1}
    end
    -- Archive validation is all-or-nothing. Persisted samples carry no actor
    -- IDs and were sealed before entering the reservoir.
    local sourceArchive=S.Table(S.Field(saved,"archive"))
    local sourceSeen=S.Table(S.Field(saved,"archiveSeen"))
    if denseCount(sourceArchive,7)~=7 or denseCount(sourceSeen,7)~=7 then
        return false,"invalid_archive"
    end
    local archive,seen=emptyArchive()
    for family=1,7 do
        local sourceBucket=S.Table(S.Field(sourceArchive,family))
        local n=denseCount(sourceBucket,ARCHIVE_LIMITS[family])
        local total=number(S.Field(sourceSeen,family),0,2147483647)
        if not n or not total or total~=math.floor(total) or total<n then
            return false,"invalid_archive"
        end
        seen[family]=total
        for i=1,n do
            local raw=S.Table(S.Field(sourceBucket,i))
            if not raw or getmetatable(raw)~=nil then return false,"invalid_archive" end
            local x=vector(S.Field(raw,"x"),C.featureCount,"input")
            local y=vector(S.Field(raw,"y"),6,"label")
            local mask=vector(S.Field(raw,"mask"),6,"mask")
            if not x or not y or not mask or not any(mask)
                or archiveFamily({y=y,mask=mask})~=family then
                return false,"invalid_archive"
            end
            archive[family][i]={x=x,y=y,mask=mask,regime="player"}
        end
    end
    local rng=number(S.Field(saved,"archiveRng"),1,RNG_MODULUS-1)
    local signature=number(S.Field(saved,"signature"),0,RNG_MODULUS-1)
    if not rng or rng~=math.floor(rng) or not signature
        or signature~=corpusSignature(restored,archive) then
        return false,"invalid_archive_signature"
    end
    -- A damaged or mismatched optional cache is ignored; evidence survives.
    local restoredModel,restoredExamples
    local snapshot=S.Table(S.Field(saved,"snapshot"))
    if snapshot and S.Field(snapshot,"signature")==signature then
        local candidate=ns.Models.Restore(S.Field(snapshot,"model"))
        local count=number(S.Field(snapshot,"examples"),0,C.maxExamples)
        if candidate and count and count==math.floor(count)
            and candidate.inputs==C.featureCount and candidate.hidden==C.hiddenCount
            and candidate.outputs==C.outputCount then
            restoredModel,restoredExamples=candidate,count
        end
    end
    self.examples,self.archive,self.archiveSeen,self.archiveRng=restored,archive,seen,rng
    self.actors={}; self.actorOrder={}; self.occurrences={}; self.occurrenceOrder={}
    self.evidenceFloor=-1; self.openAfter=self.now
    self.evidenceTime=self.now; self.nextCastAt=nil
    self:_Dirty(true)
    if restoredModel then
        self.model=restoredModel;self.modelVersion=self.modelVersion+1
        self.modelCorpusRevision=self.corpusRevision;self.modelExamples=restoredExamples
        self.dirty=false;self.snapshotRestored=true
    else
        self.snapshotRestored=false
        if snapshot then ns.Bump(self.stats,"rejectedSnapshots") end
    end
    return true
end
