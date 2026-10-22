return function(ns, T)
    local function new(inputs, hidden, outputs, seed)
        T.ok(ns.Models and type(ns.Models.New) == "function", "numeric model module is available")
        local model, reason = ns.Models.New(inputs, hidden, outputs, seed)
        T.ok(model, reason)
        return model
    end

    local function equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b or (a ~= a and b ~= b) end
        for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end

    local function plainState(value, seen)
        if type(value) == "number" then
            return value == value and value > -math.huge and value < math.huge
        end
        if type(value) ~= "table" then return false end
        seen = seen or {}
        if seen[value] then return false end
        seen[value] = true
        for key, child in pairs(value) do
            if type(key) ~= "string" and type(key) ~= "number" then return false end
            if not plainState(child, seen) then return false end
        end
        seen[value] = nil
        return true
    end

    local function brier(model, rows, kind)
        local total = 0
        for _, row in ipairs(rows) do
            local p = assert(model:Predict(row[1]))[kind][1]
            total = total + (p - row[2]) ^ 2
        end
        return total / #rows
    end

    T.case("initial models expose finite scores and serializable numeric state", function()
        math.randomseed(741)
        local expected = math.random()
        math.randomseed(741)
        local model = new(3, 4, 2, 17)
        T.eq(math.random(), expected, "initialization must not consume the global PRNG")
        T.ok(model:Valid())
        T.ok(plainState(model), "own state contains only numbers and tables")
        T.eq(model.updates, 0)
        local predictions = assert(model:Predict({0, 0.5, 1}))
        for _, kind in ipairs({"neural", "linear", "frequency"}) do
            T.eq(#predictions[kind], 2)
            for index = 1, 2 do
                T.ok(predictions[kind][index] >= 0 and predictions[kind][index] <= 1)
                T.eq(model.positives[index], 0)
                T.eq(model.totals[index], 0)
            end
        end
        T.eq(predictions.frequency[1], 0.5)
        T.eq(predictions.linear[2], 0.5)
    end)

    T.case("constructors reject malformed dimensions and seeds", function()
        new(1, 1, 1)
        for _, shape in ipairs({{0, 2, 1}, {2.5, 2, 1}, {2, -1, 1}, {2, 2, math.huge}, {"2", 2, 1}}) do
            local model, reason = ns.Models.New(shape[1], shape[2], shape[3], 1)
            T.eq(model, nil)
            T.eq(type(reason), "string")
        end
        for _, seed in ipairs({math.huge, 0 / 0, "seed", 1.5}) do
            local model, reason = ns.Models.New(2, 2, 1, seed)
            T.eq(model, nil)
            T.eq(type(reason), "string")
        end
    end)

    T.case("same seeds and copied state produce identical independent training", function()
        local first, second = new(2, 3, 2, 49), new(2, 3, 2, 49)
        T.ok(equal(first, second))
        T.ok(not equal(first, new(2, 3, 2, 50)), "different seeds initialize different networks")
        for index = 1, 12 do
            local y = {index % 2, (index + 1) % 2}
            T.ok(first:Learn({0.2, 0.8}, y, {true, true}))
            T.ok(second:Learn({0.2, 0.8}, y, {true, true}))
        end
        T.ok(equal(first, second), "training is deterministic")
        local copy = assert(first:Copy())
        T.ok(equal(first, copy))
        T.ok(copy:Learn({0.9, 0.1}, {1, 0}, {true, false}))
        T.ok(equal(first, second), "training a copy cannot mutate its source")
        T.ok(not equal(copy, first))
        T.ok(first.hiddenWeights ~= copy.hiddenWeights)
        T.ok(first.hiddenWeights[1] ~= copy.hiddenWeights[1])
        T.ok(equal(first:Predict({0.5, 0.5}), second:Predict({0.5, 0.5})))
    end)

    T.case("masked outputs keep their parameters and observation counts unchanged", function()
        local model = new(2, 3, 2, 7)
        model.linearWeights[2][1] = 0.7
        model.linearWeights[2][2] = -0.4
        model.linearBiases[2] = 0.2
        local before = assert(model:Copy())
        T.ok(model:Learn({0.3, 0.8}, {1, 0}, {true, false}))
        T.ok(equal(model.outputWeights[2], before.outputWeights[2]))
        T.eq(model.outputBiases[2], before.outputBiases[2])
        T.ok(equal(model.linearWeights[2], before.linearWeights[2]))
        T.eq(model.linearBiases[2], before.linearBiases[2])
        T.eq(model.totals[1], 1)
        T.eq(model.positives[1], 1)
        T.eq(model.totals[2], 0)
        T.eq(model.positives[2], 0)
        T.ok(not equal(model.hiddenWeights, before.hiddenWeights), "observed labels may train the shared hidden layer")
    end)

    T.case("all masked labels are a successful exact no-op", function()
        local model = new(2, 3, 2, 11)
        local before = assert(model:Copy())
        T.ok(model:Learn({0, 1}, {1, 0}, {false, false}))
        T.ok(equal(model, before))
    end)

    T.case("Laplace frequencies count each recorded label once and skip repeated epochs", function()
        local model = new(1, 2, 2, 8)
        for _, y in ipairs({1, 0, 1, 1}) do
            T.ok(model:Learn({0.4}, {y, 1}, {true, false}))
        end
        local before = assert(model:Copy())
        T.ok(model:Learn({0.4}, {1, 0}, {true, true}, false))
        T.eq(model.updates, 5)
        T.ok(equal(model.totals, before.totals))
        T.ok(equal(model.positives, before.positives))
        T.ok(not equal(model.linearWeights, before.linearWeights), "repeat epochs still perform SGD")
        local p = assert(model:Predict({0.4}))
        T.near(p.frequency[1], 4 / 6)
        T.eq(p.frequency[2], 0.5)
        T.eq(model.totals[1], 4)
        T.eq(model.positives[1], 3)
        T.ok(model:Learn({0.4}, {0, 1}, {false, true}, true))
        T.eq(model.totals[2], 1)
        T.eq(model.positives[2], 1)
    end)

    T.case("malformed examples are rejected atomically with a reason", function()
        local model = new(2, 3, 2, 10)
        local bad = {
            {x = {0.2}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, 0.3, 0.4}, y = {1, 0}, mask = {true, true}},
            {x = {[1] = 0.2, [3] = 0.3}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, 0 / 0}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, math.huge}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, -0.01}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, 1.01}, y = {1, 0}, mask = {true, true}},
            {x = {0.2, 0.3}, y = {1, 0.5}, mask = {true, false}},
            {x = {0.2, 0.3}, y = {1, math.huge}, mask = {true, false}},
            {x = {0.2, 0.3}, y = {1}, mask = {true, false}},
            {x = {0.2, 0.3}, y = {1, 0}, mask = {true, 0}},
            {x = {0.2, 0.3}, y = {1, 0}, mask = {true}},
            {x = {0.2, 0.3}, y = {1, 0}, mask = {true, false}, stats = "yes"},
        }
        for _, example in ipairs(bad) do
            local before = assert(model:Copy())
            local ok, reason = model:Learn(example.x, example.y, example.mask, example.stats)
            T.eq(ok, false)
            T.eq(type(reason), "string")
            T.ok(equal(model, before), "rejection must leave all state unchanged")
        end
        local predictions, reason = model:Predict({0.2, math.huge})
        T.eq(predictions, nil)
        T.eq(type(reason), "string")
        local ok = model:Learn(nil, {1, 0}, {true, true})
        T.eq(ok, false)
    end)

    T.case("Valid catches nonfinite parameters and malformed state", function()
        local original = new(2, 3, 2, 14)
        local corruptions = {
            function(m) m.hiddenWeights[1][1] = 0 / 0 end,
            function(m) m.outputWeights[1][1] = math.huge end,
            function(m) m.linearBiases[2] = -math.huge end,
            function(m) m.hiddenBiases[1] = nil end,
            function(m) m.linearWeights[2][3] = 0 end,
            function(m) m.positives[1] = 1 end,
            function(m) m.totals[1] = -1 end,
            function(m) m.updates = 0.5 end,
            function(m) m.learningRate = 0 / 0 end,
            function(m) m.gradientClip = 0 end,
        }
        for _, corrupt in ipairs(corruptions) do
            local model = assert(original:Copy())
            corrupt(model)
            local valid, reason = model:Valid()
            T.eq(valid, false)
            T.eq(type(reason), "string")
            local ok = model:Learn({0.2, 0.3}, {1, 0}, {true, true})
            T.eq(ok, false)
        end
    end)

    T.case("inherited fields cannot substitute for serializable own model state", function()
        local source = new(2, 3, 2, 14)
        local inherited = setmetatable({}, {__index = source})
        T.eq(inherited:Valid(), false)
        T.eq(inherited:Copy(), nil)
        T.eq(inherited:Predict({0.2, 0.3}), nil)
        T.eq(inherited:Learn({0.2, 0.3}, {1, 0}, {true, true}), false)
        T.eq(next(inherited), nil, "rejection cannot write partial own state")
        local disguised = setmetatable({}, {__index = source, __metatable = getmetatable(source)})
        T.eq(disguised:Valid(), false, "metatable identity cannot replace the own-field check")
        T.eq(disguised:Copy(), nil)
        T.ok(source:Valid())
    end)

    T.case("finite state with overflowing forward arithmetic is rejected", function()
        local model = new(2, 1, 1, 2)
        model.linearWeights[1][1], model.linearWeights[1][2] = 1e308, 1e308
        T.ok(model:Valid(), "parameters themselves are finite")
        local before = assert(model:Copy())
        local p, reason = model:Predict({1, 1})
        T.eq(p, nil)
        T.eq(type(reason), "string")
        T.eq(model:Learn({1, 1}, {0}, {true}), false)
        T.ok(equal(model, before))
    end)

    T.case("nonfinite proposed gradients reject the entire update", function()
        local model = new(2, 1, 1, 2)
        model.hiddenWeights[1] = {-1.7e308, 1.7e308}
        model.hiddenBiases[1] = 0
        model.outputWeights[1][1] = 1.7e308
        model.regularization = 1
        T.ok(model:Valid())
        T.ok(model:Predict({1, 1}))
        local before = assert(model:Copy())
        local ok, reason = model:Learn({1, 1}, {0}, {true})
        T.eq(ok, false)
        T.eq(type(reason), "string")
        T.ok(equal(model, before))
    end)

    T.case("gradient clipping bounds every individual parameter step", function()
        local model = new(2, 2, 1, 6)
        model.gradientClip = 0.025
        model.hiddenWeights = {{0.1, 0.1}, {0.1, 0.1}}
        model.hiddenBiases = {0, 0}
        model.outputWeights = {{500, 500}}
        local before = assert(model:Copy())
        T.ok(model:Learn({1, 1}, {0}, {true}))
        local largest = 0
        local function compare(a, b)
            for key, value in pairs(a) do
                if type(value) == "table" then compare(value, b[key])
                else largest = math.max(largest, math.abs(value - b[key])) end
            end
        end
        for _, field in ipairs({"hiddenWeights", "hiddenBiases", "outputWeights", "outputBiases", "linearWeights", "linearBiases"}) do
            compare(model[field], before[field])
        end
        local bound = model.learningRate * model.gradientClip
        T.ok(largest <= bound + 1e-10, "clipped SGD cannot exceed its coordinate step bound")
        T.near(largest, bound, 1e-10, "this example exercises clipping")
        T.ok(model:Valid())
    end)

    T.case("logistic baseline learns a simple feature association", function()
        local model = new(2, 4, 1, 21)
        local rows = {{{0, 0}, 0}, {{0, 1}, 0}, {{1, 0}, 1}, {{1, 1}, 1}}
        local before = brier(model, rows, "linear")
        for epoch = 1, 400 do
            for _, row in ipairs(rows) do T.ok(model:Learn(row[1], {row[2]}, {true})) end
        end
        local after = brier(model, rows, "linear")
        T.ok(after < 0.1 and after < before / 2, "synthetic association should become easier to predict")
        T.ok(model:Predict({0, 0.5}).linear[1] < 0.3)
        T.ok(model:Predict({1, 0.5}).linear[1] > 0.7)
        T.ok(model:Valid())
    end)

    T.case("hidden layer learns interacting features beyond the linear baseline", function()
        local model = new(2, 6, 1, 123)
        local rows = {{{0, 0}, 0}, {{0, 1}, 1}, {{1, 0}, 1}, {{1, 1}, 0}}
        local before = brier(model, rows, "neural")
        for epoch = 1, 1500 do
            for _, row in ipairs(rows) do T.ok(model:Learn(row[1], {row[2]}, {true})) end
        end
        local neural, linear = brier(model, rows, "neural"), brier(model, rows, "linear")
        T.ok(neural < 0.12 and neural < before * 0.6, "network should learn the small XOR fixture")
        T.ok(neural + 0.08 < linear, "hidden interactions should improve this synthetic fixture")
        T.ok(model:Valid())
    end)
end
