return function(ns, T)
    local function core()
        assert(ns.Core, "core is implemented")
        local c = ns.Core.New()
        c:SetCoverage(true)
        return c
    end
    local function context(c, at, actor, role)
        actor = actor or "Player-test-1"
        role = role or "self"
        c:Context({actor=actor,class="PRIEST",role=role,combat=true,at=at,bound=true,
                   regime=role=="self" and "player" or "other"})
        return actor
    end
    local function start(c, at, actor, role)
        context(c, at, actor, role); c:Tick(at, true)
    end
    local function cast(c, id, at, actor, family, revision, extra)
        local r = {id=id,actor=actor or "Player-test-1",at=at,family=family or 1,revision=revision or 1,source="native-cast"}
        if extra then for k,v in pairs(extra) do r[k]=v end end
        return c:Cast(r)
    end
    T.case("one stable player window receives one positive and independent negatives", function()
        local c=core(); start(c,0); cast(c,"a",1)
        c:Tick(2.25,true)
        T.eq(#c.examples,1)
        T.eq(c.examples[1].y[1],1)
        for i=1,6 do T.eq(c.examples[1].mask[i],true) end
        for i=2,6 do T.eq(c.examples[1].y[i],0) end
    end)
    T.case("an event at the anchor is history and cannot predict itself", function()
        local c=core(); context(c,0); cast(c,"anchor",0); c:Tick(0,true); c:Tick(2.25,true)
        T.eq(c.examples[1].y[1],0)
    end)
    T.case("duplicate sightings and alias routes do not multiply evidence", function()
        local c=core(); start(c,0)
        T.eq(cast(c,"same",1),true)
        local ok,reason=cast(c,"same",1)
        T.eq(ok,false); T.eq(reason,"duplicate")
        c:Tick(2.25,true)
        T.eq(#c.occurrenceOrder,1); T.eq(#c.examples,1); T.eq(c.examples[1].y[1],1)
        T.eq(c:Status().casts,1)
    end)
    T.case("coverage gaps keep positives but never manufacture other negatives", function()
        local c=core(); start(c,0); c:Gap("unreadable"); cast(c,"one",1)
        c:Tick(2.25,true)
        T.eq(c.examples[1].mask[1],true)
        for i=2,6 do T.eq(c.examples[1].mask[i],false) end
    end)
    T.case("enemy absence is unknown and enemy positives do not train player model", function()
        local c=core(); start(c,0,"Player-other","hostile"); cast(c,"enemy",1,"Player-other")
        c:Tick(2.25,true)
        T.eq(c.examples[1].regime,"other")
        T.eq(c.examples[1].mask[1],true)
        T.eq(c.examples[1].mask[2],false)
        for i=1,100 do c:Tick(3+i*.1,false) end
        T.eq(c:Status().trainingExamples,0)
        T.eq(c:Forecast("Player-other",14).usable,false)
    end)
    T.case("interval uncertainty across the boundary censors only its family", function()
        local c=core(); start(c,0); cast(c,"uncertain",2,nil,1,1,{minAt=1.9,maxAt=2.1})
        c:Tick(2.25,true)
        T.eq(c.examples[1].mask[1],false); T.eq(c.examples[1].mask[2],true)
    end)
    T.case("late correction replaces a trained label and rebuilds cleanly", function()
        local c=core(); start(c,0); cast(c,"revised",1); c:Tick(2.25,true)
        for i=1,30 do c:Tick(3+i*.1,false) end
        T.ok(c.model, "completed candidate is published for shadow diagnostics")
        T.eq(cast(c,"revised",3,nil,1,2),true)
        T.eq(#c.examples,1); T.eq(c.examples[1].y[1],0)
        T.eq(c.model,nil,"superseded adaptive generation is invalidated immediately")
        for i=1,30 do c:Tick(7+i*.1,false) end
        T.ok(c.model)
        T.eq(c.model.positives[1],0)
    end)
    T.case("correcting an existing occurrence preserves distinct later applications", function()
        local c=core(); start(c,0); cast(c,"old",1); cast(c,"new",1.5)
        c:Tick(2.25,true); cast(c,"old",3,nil,1,2)
        T.eq(c.examples[1].y[1],1)
        T.eq(#c.occurrenceOrder,2)
    end)
    T.case("future evidence never rewrites an anchored feature vector", function()
        local c=core(); start(c,0)
        local before={}; for i,v in ipairs(c.actors["Player-test-1"].window.x) do before[i]=v end
        cast(c,"future",1); context(c,1); c:Tick(2.25,true)
        for i=1,#before do T.eq(c.examples[1].x[i],before[i]) end
    end)
    T.case("aura witnesses revise one identity and never become cast labels", function()
        local c=core(); start(c,0)
        c:Aura({recipient="Player-test-1",id="aura:1",spellID=22812,at=1,expires=8,newApplication=false})
        c:Aura({recipient="Player-test-1",id="aura:1",spellID=22812,at=1.5,expires=10,newApplication=false})
        c:Tick(2.25,true)
        T.eq(#c.occurrenceOrder,1)
        for i=1,6 do T.eq(c.examples[1].y[i],0) end
        T.eq(c:GetContext("Player-test-1",2).defensiveWitness.expires,10)
    end)
    T.case("training defers in combat while observations continue", function()
        local c=core(); start(c,0); cast(c,"combat",1); c:Tick(2.25,true)
        for i=1,30 do c:Tick(3+i*.1,true) end
        T.eq(c.model,nil); T.eq(c:Status().trainingSteps,0)
        for i=1,30 do c:Tick(7+i*.1,false) end
        T.ok(c.model); T.ok(c:Status().trainingSteps>0)
    end)
    T.case("persistence is compatible deidentified replay with explicit session reset", function()
        local c=core(); start(c,0); cast(c,"secret-cast-id",1); c:Tick(2.25,true)
        local saved=c:Export()
        T.eq(saved.examples[1].actor,nil); T.eq(saved.examples[1].id,nil)
        T.eq(saved.actors,nil); T.eq(saved.occurrences,nil)
        local d=core(); T.eq(d:Restore(saved),true)
        T.eq(#d.actorOrder,0); T.eq(#d.examples,1)
        for i=1,30 do c:Tick(3+i*.1,false); d:Tick(3+i*.1,false) end
        local p=c.model:Predict(c.examples[1].x); local q=d.model:Predict(d.examples[1].x)
        for i=1,6 do T.near(p.neural[i],q.neural[i],1e-12) end
        saved.compat="incompatible"
        local e=core(); T.eq(e:Restore(saved),false); T.eq(#e.examples,0)
    end)
    T.case("copied projections cannot mutate context or confer consumer authority", function()
        local c=core(); start(c,0)
        local p=c:GetContext("Player-test-1",0); p.class="WARRIOR"
        T.eq(c.actors["Player-test-1"].class,"PRIEST")
        local f=c:Forecast("Player-test-1",0)
        T.eq(f.usable,false); T.eq(f.mode,"shadow")
        T.eq(f.outputs[1].score,nil,"untrained random outputs have no authority")
    end)
    T.case("actor and occurrence capacities are strict", function()
        local c=core()
        for i=1,100 do context(c,i,"Player-"..i,"hostile") end
        T.eq(#c.actorOrder,ns.Config.maxActors)
        for i=1,300 do cast(c,"cast-"..i,i,"Player-100") end
        T.eq(#c.occurrenceOrder,ns.Config.maxOccurrences)
    end)
    T.case("losing a binding retains known actor semantics without retaining coverage", function()
        local c=core(); start(c,0)
        c:Context({actor="Player-test-1",at=1,bound=false})
        local a=c:GetContext("Player-test-1",1)
        T.eq(a.class,"PRIEST"); T.eq(a.role,"self"); T.eq(a.bound,false)
        c:Tick(2.25,true)
        for i=1,6 do T.eq(c.examples[1].mask[i],false) end
    end)
    T.case("same aura preserves readable expiry but a new application gets its own end", function()
        local c=core(); context(c,0)
        c:Aura({recipient="Player-test-1",id="a",spellID=22812,at=1,expires=10,newApplication=false})
        c:Aura({recipient="Player-test-1",id="a",spellID=22812,at=2,newApplication=false})
        T.eq(c:GetContext("Player-test-1",2).defensiveWitness.expires,10)
        c:Aura({recipient="Player-test-1",id="a",spellID=22812,at=11,newApplication=true})
        T.eq(c:GetContext("Player-test-1",11).defensiveWitness.expires,nil)
    end)
    T.case("unknown combat cannot open a player training window", function()
        local c=core()
        c:Context({actor="Player-test-1",role="self",at=0,bound=true})
        c:Tick(0,true)
        T.eq(c:Status().pending,0)
        start(c,1)
        c:Context({actor="Player-test-1",role="self",at=2,bound=true})
        c:Tick(3.25,nil)
        for i=1,6 do T.eq(c.examples[1].mask[i],false) end
        T.eq(c:Status().trainingSteps,0)
    end)
    T.case("pre-update predictions remain fixed through training and label correction", function()
        local c=core()
        for i=1,12 do
            local at=(i-1)*3; start(c,at)
            if i<=4 then cast(c,"support-"..i,at+1) end
            c:Tick(at+2.25,true)
        end
        for i=1,20 do c:Tick(36+i*.1,false) end
        T.ok(c.model)
        start(c,40)
        local predicted=c.actors["Player-test-1"].window.predictions.neural[1]
        T.ok(predicted and predicted>0 and predicted<1)
        cast(c,"evaluation",41); c:Tick(42.25,true)
        local w=c.examples[#c.examples]
        T.eq(w.predictions.neural[1],predicted)
        T.eq(c:Status().families[1].scored,1)
        T.near(c:Status().families[1].neuralLoss,(1-predicted)^2)
        for i=1,20 do c:Tick(43+i*.1,false) end
        T.eq(w.predictions.neural[1],predicted)
        cast(c,"evaluation",43,nil,1,2)
        T.eq(w.y[1],0); T.eq(c:Status().families[1].scored,1)
        T.near(c:Status().families[1].neuralLoss,predicted^2)
    end)
    T.case("evicting needed evidence censors dependent labels and later lost revisions", function()
        local c=core(); start(c,0); cast(c,"retired",1); c:Tick(2.25,true)
        for i=1,128 do cast(c,"later-"..i,10+i) end
        T.eq(c.examples[1].mask[1],false)
        local ok,reason=cast(c,"retired",1.5,nil,1,2)
        T.eq(ok,false); T.eq(reason,"revision_history_lost")
        T.eq(c.examples[1].mask[1],false)
        T.eq(c.model,nil)
    end)
    T.case("malformed saved examples do not partially replace a valid corpus", function()
        local c=core(); start(c,0); c:Tick(2.25,true)
        local saved=c:Export(); saved.examples[1].x[8]=0/0
        T.eq(c:Restore(saved),false)
        T.eq(#c.examples,1)
        T.eq(c.examples[1].x[8],0)
    end)
    T.case("eviction cannot resurrect a superseded occurrence from stale evidence", function()
        local c=core(); start(c,0); cast(c,"withdrawn",1); c:Tick(2.25,true)
        cast(c,"withdrawn",1,nil,1,2,{retracted=true})
        T.eq(c.examples[1].y[1],0)
        for i=1,128 do cast(c,"fill-"..i,10+i) end
        local ok,reason=cast(c,"withdrawn",1)
        T.eq(ok,false); T.eq(reason,"outside_retained_history")
        T.eq(c.examples[1].mask[1],false)
        T.eq(c.examples[1].y[1],0)
    end)
    T.case("retirement watermark includes time before an occurrence was backdated", function()
        local c=core(); context(c,100)
        cast(c,"backdated",100)
        cast(c,"backdated",1,nil,1,2,{retracted=true})
        for i=1,128 do cast(c,"fill-"..i,2) end
        local ok=cast(c,"backdated",100)
        T.eq(ok,false)
        T.ok(c:Status().evidenceFloor>=100)
        T.eq(cast(c,"fresh-after-floor",101),true)
    end)
    T.case("actor capacity pressure cannot double-weight one event in overlapping windows", function()
        local c=core(); start(c,0)
        for i=1,16 do context(c,.01+i*.001,"Player-other-"..i,"hostile") end
        context(c,.1); c:Tick(.1,true); cast(c,"once",1); c:Tick(2.35,true)
        local windows,positives=0,0
        for _,w in ipairs(c.examples) do
            if w.regime=="player" then windows=windows+1; if w.mask[1] then positives=positives+w.y[1] end end
        end
        T.eq(windows,1); T.eq(positives,1)
        T.eq(c:Status().families[1].positive,1)
    end)
    T.case("a later binding recovers a positive witness already retained for that actor", function()
        local c=core()
        c:Aura({recipient="Player-future-target",id="early",spellID=22812,at=1,expires=10,newApplication=false})
        context(c,2,"Player-future-target","hostile")
        local a=c:GetContext("Player-future-target",2)
        T.ok(a.defensiveWitness)
        T.eq(a.defensiveWitness.expires,10)
        T.eq(a.defensiveWitness.source,"bjarkiPortraits")
    end)
end
