local _, ns = ...

ns.Config = {
    version = "0.1.0-shadow", schema = 1, horizon = 2, grace = 0.25,
    maxActors = 16, maxOccurrences = 128, maxExamples = 256,
    featureCount = 48, hiddenCount = 12, outputCount = 6,
    seed = 73013, epochs = 4, stepsPerTick = 4, contextTTL = 1,
    compat = "learn1/forever16001-provisional1/features48-v1/cast-delivery-v1/h2/player-combat-v1/mlp12-sgd4-v1",
}

-- Check accessibility before comparison, indexing, formatting or truthiness.
-- Once a native value crosses this boundary, the core works on ordinary data.
local S = {}
ns.Safe = S
function S.Readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(issecrettable) == "function" and type(value) == "table" then
        local ok, secret = pcall(issecrettable, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok or accessible == false then return false end
    end
    return true
end
function S.Number(value)
    if S.Readable(value) and type(value) == "number" and value == value
       and value ~= math.huge and value ~= -math.huge then return value end
end
function S.String(value)
    if S.Readable(value) and type(value) == "string" then return value end
end
function S.Boolean(value)
    if S.Readable(value) and type(value) == "boolean" then return value end
end
function S.Table(value)
    if S.Readable(value) and type(value) == "table" then return value end
end
function S.Field(value, key)
    if not S.Table(value) then return nil end
    local ok, result = pcall(function() return value[key] end)
    if ok and S.Readable(result) then return result end
end
function S.Call(fn, ...)
    if not S.Readable(fn) or type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok and S.Readable(result) then return result end
end

-- Internal ordinary tables only. Public/native data is normalized field by field.
function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = ns.Copy(item) end
    return out
end
function ns.Bump(counters, key, amount)
    counters[key] = math.min(2147483647, (counters[key] or 0) + (amount or 1))
end
