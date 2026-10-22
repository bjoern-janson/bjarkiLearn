local T = { passed = 0, assertions = 0, failures = {} }
function T.case(name, fn)
    local ok, err = pcall(fn)
    if ok then T.passed = T.passed + 1
    else T.failures[#T.failures + 1] = name .. ": " .. tostring(err) end
end
function T.ok(value, message)
    T.assertions = T.assertions + 1
    assert(value, message or "expected truthy value")
end
function T.eq(actual, expected, message)
    T.assertions = T.assertions + 1
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
function T.near(actual, expected, tolerance, message)
    T.assertions = T.assertions + 1
    assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-10), message or "values outside tolerance")
end
return T
