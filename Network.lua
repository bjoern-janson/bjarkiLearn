local _, ns = ...

-- Small, deterministic models. Only numeric tables are stored on an instance;
-- methods live in this metatable and are not part of serialized own state.
local Models = {}
ns.Models = Models
local Methods = {}
Methods.__index = Methods

local MAX_SAFE_INTEGER = 9007199254740991
local MAX_DIMENSION = 256
local PRNG_MODULUS = 2147483647
local STATE_FIELDS = {
    schemaVersion = true, inputs = true, hidden = true, outputs = true,
    seed = true, rngState = true, learningRate = true, regularization = true,
    linearRegularization = true, gradientClip = true,
    hiddenWeights = true, hiddenBiases = true,
    outputWeights = true, outputBiases = true,
    linearWeights = true, linearBiases = true,
    positives = true, totals = true, updates = true,
}

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function integer(value, low, high)
    return finite(value) and value >= low and value <= high and value == math.floor(value)
end

local function dimension(value)
    return integer(value, 1, MAX_DIMENSION)
end

local function normalized(value)
    return finite(value) and value >= 0 and value <= 1
end

local function binary(value)
    return type(value) == "number" and (value == 0 or value == 1)
end

local function boolean(value)
    return type(value) == "boolean"
end

local function count(value)
    return integer(value, 0, MAX_SAFE_INTEGER)
end

-- Check every key, not Lua's undefined length for sparse arrays. Inputs and
-- parameter arrays must be plain, dense tables with no extra fields.
local function vector(values, size, check)
    if type(values) ~= "table" or getmetatable(values) ~= nil then return false end
    for index = 1, size do
        if not check(rawget(values, index)) then return false end
    end
    for key in pairs(values) do
        if not integer(key, 1, size) then return false end
    end
    return true
end

local function matrix(values, rows, columns)
    return vector(values, rows, function(row) return vector(row, columns, finite) end)
end

local function valid(model)
    if type(model) ~= "table" then return false, "invalid_model" end
    local meta = getmetatable(model)
    if meta ~= nil and meta ~= Methods then return false, "invalid_model_metatable" end
    -- Inherited values would disappear when SavedVariables serializes own
    -- state. A protected metatable can also disguise itself as Methods.
    for field in pairs(STATE_FIELDS) do
        if rawget(model, field) == nil then return false, "missing_model_field" end
    end
    for field in next, model do
        if not STATE_FIELDS[field] then return false, "invalid_model_field" end
    end
    if model.schemaVersion ~= 1 or not dimension(model.inputs) or not dimension(model.hidden)
        or not dimension(model.outputs) then return false, "invalid_model_shape" end
    if not integer(model.seed, 1, PRNG_MODULUS - 1)
        or not integer(model.rngState, 1, PRNG_MODULUS - 1) then return false, "invalid_model_seed" end
    if not finite(model.learningRate) or model.learningRate <= 0
        or not finite(model.gradientClip) or model.gradientClip <= 0
        or not finite(model.regularization) or model.regularization < 0
        or not finite(model.linearRegularization) or model.linearRegularization < 0 then
        return false, "invalid_model_settings"
    end
    if not matrix(model.hiddenWeights, model.hidden, model.inputs)
        or not vector(model.hiddenBiases, model.hidden, finite)
        or not matrix(model.outputWeights, model.outputs, model.hidden)
        or not vector(model.outputBiases, model.outputs, finite)
        or not matrix(model.linearWeights, model.outputs, model.inputs)
        or not vector(model.linearBiases, model.outputs, finite) then
        return false, "invalid_model_parameters"
    end
    if not count(model.updates) or not vector(model.positives, model.outputs, count)
        or not vector(model.totals, model.outputs, count) then return false, "invalid_model_statistics" end
    for index = 1, model.outputs do
        if model.positives[index] > model.totals[index] or model.totals[index] > model.updates then
            return false, "invalid_model_statistics"
        end
    end
    return true
end

local function copyTable(source)
    local target = {}
    for key, value in next, source do
        target[key] = type(value) == "table" and copyTable(value) or value
    end
    return target
end

function Methods:Valid()
    return valid(self)
end

function Methods:Copy()
    local ok, reason = valid(self)
    if not ok then return nil, reason end
    return setmetatable(copyTable(self), Methods)
end

function Models.New(inputs, hidden, outputs, seed)
    if not dimension(inputs) or not dimension(hidden) or not dimension(outputs) then
        return nil, "invalid_dimensions"
    end
    if seed == nil then seed = 1 end
    if not integer(seed, -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER) then return nil, "invalid_seed" end
    -- Avoid quotient rounding in Lua 5.1's % for extreme accepted integers.
    seed = math.fmod(seed, PRNG_MODULUS)
    if seed < 0 then seed = seed + PRNG_MODULUS end
    if seed == 0 then seed = 1 end
    local model = setmetatable({
        schemaVersion = 1, inputs = inputs, hidden = hidden, outputs = outputs,
        seed = seed, rngState = seed,
        learningRate = 0.08, regularization = 0.0001,
        linearRegularization = 0.001, gradientClip = 1,
        hiddenWeights = {}, hiddenBiases = {}, outputWeights = {}, outputBiases = {},
        linearWeights = {}, linearBiases = {}, positives = {}, totals = {}, updates = 0,
    }, Methods)
    local function randomWeight(scale)
        -- Park-Miller products stay below 2^53, including in Lua 5.1 doubles.
        model.rngState = (model.rngState * 16807) % PRNG_MODULUS
        return (2 * model.rngState / PRNG_MODULUS - 1) * scale
    end
    local hiddenScale = math.sqrt(6 / (inputs + hidden))
    local outputScale = math.sqrt(6 / (hidden + outputs))
    for unit = 1, hidden do
        local row = {}
        for input = 1, inputs do row[input] = randomWeight(hiddenScale) end
        model.hiddenWeights[unit], model.hiddenBiases[unit] = row, 0
    end
    for output = 1, outputs do
        local neural, linear = {}, {}
        for unit = 1, hidden do neural[unit] = randomWeight(outputScale) end
        for input = 1, inputs do linear[input] = 0 end
        model.outputWeights[output], model.outputBiases[output] = neural, 0
        model.linearWeights[output], model.linearBiases[output] = linear, 0
        model.positives[output], model.totals[output] = 0, 0
    end
    return model
end

local function sigmoid(value)
    if value >= 0 then return 1 / (1 + math.exp(-value)) end
    local exponent = math.exp(value)
    return exponent / (1 + exponent)
end

local function tanh(value)
    if value > 20 then return 1 end
    if value < -20 then return -1 end
    local exponent = math.exp(2 * value)
    return (exponent - 1) / (exponent + 1)
end

local function dot(weights, values, bias, size)
    local result = bias
    for index = 1, size do
        result = result + weights[index] * values[index]
        if not finite(result) then return nil end
    end
    return result
end

local function forward(model, x)
    local hidden = {}
    for unit = 1, model.hidden do
        local value = dot(model.hiddenWeights[unit], x, model.hiddenBiases[unit], model.inputs)
        if value == nil then return nil, "nonfinite_prediction" end
        hidden[unit] = tanh(value)
    end
    local result = {neural = {}, linear = {}, frequency = {}}
    for output = 1, model.outputs do
        local neural = dot(model.outputWeights[output], hidden, model.outputBiases[output], model.hidden)
        local linear = dot(model.linearWeights[output], x, model.linearBiases[output], model.inputs)
        if neural == nil or linear == nil then return nil, "nonfinite_prediction" end
        result.neural[output], result.linear[output] = sigmoid(neural), sigmoid(linear)
        result.frequency[output] = (model.positives[output] + 1) / (model.totals[output] + 2)
    end
    return result, hidden
end

function Methods:Predict(x)
    local ok, reason = valid(self)
    if not ok then return nil, reason end
    if not vector(x, self.inputs, normalized) then return nil, "invalid_inputs" end
    local predictions, hiddenOrReason = forward(self, x)
    if not predictions then return nil, hiddenOrReason end
    return predictions
end

function Methods:Learn(x, y, mask, recordStatistics)
    local ok, reason = valid(self)
    if not ok then return false, reason end
    if not vector(x, self.inputs, normalized) then return false, "invalid_inputs" end
    if not vector(y, self.outputs, binary) then return false, "invalid_labels" end
    if not vector(mask, self.outputs, boolean) then return false, "invalid_mask" end
    if recordStatistics ~= nil and type(recordStatistics) ~= "boolean" then
        return false, "invalid_statistics_flag"
    end
    local observed = 0
    for output = 1, self.outputs do if mask[output] then observed = observed + 1 end end
    if observed == 0 then return true end
    if self.updates >= MAX_SAFE_INTEGER then return false, "counter_overflow" end
    local predictions, hidden = forward(self, x)
    if not predictions then return false, hidden end

    -- Work on a private candidate. No caller-visible state changes until the
    -- complete update, including parameters and statistics, has validated.
    local candidate = setmetatable(copyTable(self), Methods)
    local deltas = {}
    local function step(target, index, previous, gradient)
        if not finite(gradient) then return false end
        local clipped = math.max(-self.gradientClip, math.min(self.gradientClip, gradient))
        local change = self.learningRate * clipped
        local updated = previous - change
        if not finite(change) or not finite(updated) then return false end
        target[index] = updated
        return true
    end
    for output = 1, self.outputs do
        deltas[output] = mask[output] and (predictions.neural[output] - y[output]) / observed or 0
        if mask[output] then
            -- Cross-entropy sigmoid gradients, with weight-only L2 penalties.
            -- Omitted heads receive neither data gradients nor regularization.
            for unit = 1, self.hidden do
                local weight = self.outputWeights[output][unit]
                if not step(candidate.outputWeights[output], unit, weight,
                    deltas[output] * hidden[unit] + self.regularization * weight) then
                    return false, "nonfinite_update"
                end
            end
            if not step(candidate.outputBiases, output, self.outputBiases[output], deltas[output]) then
                return false, "nonfinite_update"
            end
            local linearDelta = predictions.linear[output] - y[output]
            for input = 1, self.inputs do
                local weight = self.linearWeights[output][input]
                if not step(candidate.linearWeights[output], input, weight,
                    linearDelta * x[input] + self.linearRegularization * weight) then
                    return false, "nonfinite_update"
                end
            end
            if not step(candidate.linearBiases, output, self.linearBiases[output], linearDelta) then
                return false, "nonfinite_update"
            end
        end
    end
    -- Hidden parameters are shared: observed heads may change the hidden
    -- representation and hence an omitted head's prediction, but not its head.
    for unit = 1, self.hidden do
        local propagated = 0
        for output = 1, self.outputs do
            if mask[output] then
                propagated = propagated + self.outputWeights[output][unit] * deltas[output]
                if not finite(propagated) then return false, "nonfinite_update" end
            end
        end
        local delta = propagated * (1 - hidden[unit] * hidden[unit])
        if not finite(delta) then return false, "nonfinite_update" end
        for input = 1, self.inputs do
            local weight = self.hiddenWeights[unit][input]
            if not step(candidate.hiddenWeights[unit], input, weight,
                delta * x[input] + self.regularization * weight) then return false, "nonfinite_update" end
        end
        if not step(candidate.hiddenBiases, unit, self.hiddenBiases[unit], delta) then
            return false, "nonfinite_update"
        end
    end
    candidate.updates = self.updates + 1
    if recordStatistics ~= false then
        for output = 1, self.outputs do
            if mask[output] then
                candidate.totals[output] = self.totals[output] + 1
                candidate.positives[output] = self.positives[output] + y[output]
            end
        end
    end
    ok, reason = valid(candidate)
    if not ok then return false, reason end
    for field in pairs(STATE_FIELDS) do self[field] = candidate[field] end
    return true
end
