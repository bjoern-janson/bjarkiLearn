return function(ns, T)
    T.case("readable boundaries reject inaccessible and nonfinite values", function()
        T.ok(ns.Safe, "readable boundary is implemented")
        local S = ns.Safe
        T.eq(S.Number(0/0), nil)
        T.eq(S.Number(math.huge), nil)
        T.eq(S.Number(0), 0)
        T.eq(S.Boolean(false), false)
        local poison = {}
        local old = issecretvalue
        issecretvalue = function(v) return v == poison end
        T.eq(S.Table(poison), nil)
        T.eq(S.Field(poison, "anything"), nil)
        issecretvalue = old
    end)
    T.case("class semantics establish candidates without inventing readiness", function()
        T.ok(ns.Rules, "semantic rules are implemented")
        local p = ns.Rules.Candidates("PRIEST")
        T.eq(p.fear.status, "candidate")
        T.eq(p.silence.status, "conditional")
        T.eq(p.root.status, "unknown")
        T.eq(p.fear.ready, nil)
        p.fear.status = "corrupted"
        T.eq(ns.Rules.Candidates("PRIEST").fear.status, "candidate")
    end)
    T.case("explicit cast vocabulary separates ability use and effects", function()
        T.ok(ns.Rules, "cast rules are implemented")
        T.eq(ns.Rules.Classify(8122), 1)
        T.eq(ns.Rules.Classify(15487), 4)
        T.eq(ns.Rules.Classify(1766), 5)
        T.eq(ns.Rules.Classify(22812), 6)
        T.eq(ns.Rules.Classify(16689), nil, "Nature's Grasp activation is not a root")
        T.eq(ns.Rules.Classify(8056), nil, "Frost Shock is not Earth Shock")
        T.eq(ns.Rules.Classify(24394), nil, "effect IDs do not become cast labels")
        T.eq(ns.Rules.Classify(9999999), nil)
    end)
    T.case("features contain semantic context and explicit missingness", function()
        T.ok(ns.Rules, "features are implemented")
        local a = {class="PRIEST",role="hostile",regime="other",history={}}
        local unknown = ns.Rules.Features(a, 10)
        local zero = ns.Rules.Features({class="PRIEST",role="hostile",health=0,power=0,combat=false,history={}}, 10)
        T.eq(#unknown, 48)
        T.eq(#zero, 48)
        local changed = 0
        for i=1,48 do
            T.ok(type(unknown[i]) == "number" and unknown[i] >= 0 and unknown[i] <= 1)
            if unknown[i] ~= zero[i] then changed = changed + 1 end
        end
        T.eq(changed, 3, "known false/zero differs from missing")
        a.actor="unrelated-identity"; a.palette={r=1,g=0,b=1}; a.name="anything"
        local equivalent = ns.Rules.Features(a, 10)
        for i=1,48 do T.eq(equivalent[i], unknown[i]) end
    end)
end
