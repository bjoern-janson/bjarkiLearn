return function(ns, T)
    local C=ns.Config
    T.case("1100 combat windows retain strict actor occurrence and example bounds", function()
        local c=ns.Core.New(); c:SetCoverage(true)
        for i=1,1100 do
            local at=(i-1)*3
            c:Context({actor="Player-self",class="PRIEST",role="self",combat=true,at=at,bound=true})
            c:Context({actor="Player-other-"..i,class="WARRIOR",role="hostile",at=at,bound=true})
            c:Tick(at,true)
            c:Cast({actor="Player-self",id="occurrence-"..i,at=at+1,family=(i-1)%6+1,revision=1})
            c:Tick(at+2.25,true)
            if i%7==0 then
                c:Cast({actor="Player-self",id="occurrence-"..i,at=at+2.1,family=(i-1)%6+1,revision=2})
            end
            T.ok(#c.actorOrder<=C.maxActors)
            T.ok(#c.occurrenceOrder<=C.maxOccurrences)
            T.ok(#c.examples<=C.maxExamples)
            T.ok(c:Status().pending<=C.maxActors)
        end
        T.eq(#c.actorOrder,16); T.eq(#c.occurrenceOrder,128); T.eq(#c.examples,256)
        T.eq(c:Status().trainingSteps,0)
        for i=1,260 do c:Tick(3300+i*.1,false) end
        T.ok(c.model and c.model:Valid())
        T.eq(c.candidate,nil)
        T.ok(c:Status().trainingSteps<=256*C.epochs)
        local saved=c:Export()
        T.eq(#saved.examples,256)
    end)
    T.case("rebuilding revised learning can reverse a formerly useful association", function()
        local function corpus(reverse)
            local data={schema=C.schema,compat=C.compat,examples={}}
            for i=1,128 do
                local x={}; for j=1,C.featureCount do x[j]=0 end
                local high=i%2
                x[1]=high; x[11]=1
                local y={reverse and 1-high or high,0,0,0,0,0}
                data.examples[#data.examples+1]={x=x,y=y,mask={true,false,false,false,false,false},regime="player"}
            end
            return data
        end
        local c=ns.Core.New()
        T.eq(c:Restore(corpus(false)),true)
        for i=1,130 do c:Tick(i*.1,false) end
        T.ok(c.model)
        local a,b={},{}
        for i=1,C.featureCount do a[i]=0; b[i]=0 end
        a[1]=.25; b[1]=.75; a[11]=1; b[11]=1
        local firstA,firstB=c.model:Predict(a).neural[1],c.model:Predict(b).neural[1]
        T.ok(firstB>firstA+.15, "initial association is learned on distinct probe values")
        local saved=corpus(true)
        T.eq(c:Restore(saved),true); T.eq(c.model,nil)
        for i=1,130 do c:Tick(20+i*.1,false) end
        local secondA,secondB=c.model:Predict(a).neural[1],c.model:Predict(b).neural[1]
        T.ok(secondA>secondB+.15, "revised corpus reverses the prior association")
        T.ok(((1-secondA)^2+secondB^2)<((1-firstA)^2+firstB^2))
        T.eq(c.model.totals[1],128,"four epochs still represent 128 unique examples")
        T.eq(c.model.updates,128*C.epochs)
        local clean=ns.Core.New(); T.eq(clean:Restore(saved),true)
        for i=1,130 do clean:Tick(i*.1,false) end
        for _,x in ipairs({a,b}) do
            local p,q=c.model:Predict(x),clean.model:Predict(x)
            for _,name in ipairs({"neural","linear","frequency"}) do
                for i=1,6 do T.near(p[name][i],q[name][i],1e-12) end
            end
        end
    end)
end
