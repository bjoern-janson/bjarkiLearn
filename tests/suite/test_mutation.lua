-- Opt-in sensitivity control: mutate only the actual publisher's loaded source.
-- Disk sources are untouched. The normal suite must fail at the consumer effect.
assert(arg[1] and arg[2],'usage: lua tests/suite/test_mutation.lua PORTRAITS_PATH CC_PATH')
local originalLoad,originalPrint=loadfile,print
local publisher=arg[1]..'/EvidencePublisher.lua'
local mutations=0
loadfile=function(path,...)
    if path~=publisher then return originalLoad(path,...) end
    local file=assert(io.open(path,'r')); local source=file:read('*a'); file:close()
    local changed,count=source:gsub('auraInstanceID=field%(aura, "auraInstanceID"%),',
        'auraInstanceID=nil, -- mutation: drop native application identity',1)
    assert(count==1,'publisher mutation anchor changed; update the control')
    mutations=mutations+1
    return (loadstring or load)(changed,'@'..path..' [identity-drop mutant]')
end
-- The normal suite prints each expected failure; show only the control result.
print=function() end
local ok,why=pcall(function() return dofile('tests/suite/test_bridge.lua') end)
loadfile,print=originalLoad,originalPrint
assert(mutations>0,'control did not load the actual mutated publisher')
assert(not ok,'negative control unexpectedly passed')
assert(tostring(why):find('Learn aura follows Portraits publication',1,true),
    'control failed for an unintended reason: '..tostring(why))
print('suite mutation: PASS; missing publisher application identity broke Learn consumer assertion ('.._VERSION..')')
