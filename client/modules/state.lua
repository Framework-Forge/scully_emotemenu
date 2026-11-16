local contract = pr_lib.load('shared.modules.emote_state')
local prefix = 'scully_emotemenu:'
local localPrefix = prefix .. 'local:'
local pending, revisions, observed = {}, {}, {}
pr_lib.cache.set(prefix .. 'pending', pending)
pr_lib.cache.set(prefix .. 'revisions', revisions)
pr_lib.cache.set(prefix .. 'observed', observed)

local function ownId() return pr_lib.cache.serverId or GetPlayerServerId(PlayerId()) end
local function notify(id, key, value) TriggerEvent('scully_emotemenu:cacheChanged', id, key, value) end
local methods = {}
function methods:get(key) return pr_lib.cache.get(localPrefix .. key) end
function methods:set(key, value, replicate)
    if contract.keys[key] then
        local valid,normalized=contract.normalize(key,value)
        if not valid then return false end
        value=normalized
    end
    local old = self:get(key)
    if old == value then return true end
    pr_lib.cache.set(localPrefix .. key, value)
    if contract.keys[key] then
        notify(ownId(), key, value)
        if replicate ~= false and key ~= 'allowNSFWEmotes' then pending[key] = {key=key,value=value,clear=value == nil} end
    end
    return true
end
function methods:on(key, callback) return pr_lib.cache.onChange(localPrefix .. key, callback) end
local facade = setmetatable({}, {
    __index=function(_,key) return methods[key] or pr_lib.cache.get(localPrefix .. key) end,
    __newindex=function(self,key,value) methods.set(self,key,value,true) end,
})

EmoteSync = {}
function EmoteSync.get(id,key)
    if id == ownId() then return facade:get(key) end
    local record = pr_lib.cache.get(prefix .. 'remote:' .. id)
    return record and record.fields[key]
end
function EmoteSync.apply(id,record)
    if id == ownId() or type(record) ~= 'table' or type(record.fields) ~= 'table' then return end
    if type(record.revision) ~= 'number' or record.revision <= (revisions[id] or -1) then return end
    local old = pr_lib.cache.get(prefix .. 'remote:' .. id)
    revisions[id] = record.revision
    pr_lib.cache.set(prefix .. 'remote:' .. id,record)
    for key in pairs(contract.keys) do
        local previous = old and old.fields[key]
        if not contract.equal(previous,record.fields[key]) then notify(id,key,record.fields[key]) end
    end
end
function EmoteSync.forget(id,keepRevision)
    if not keepRevision then revisions[id]=nil end
    pr_lib.cache.clear(prefix .. 'remote:' .. id)
    TriggerEvent('scully_emotemenu:cacheRemoved',id)
end

RegisterNetEvent('scully_emotemenu:stateUpdate',function(id,record)
    if source ~= 65535 or type(id) ~= 'number' then return end
    if observed[id] then EmoteSync.apply(id,record) end
end)
RegisterNetEvent('scully_emotemenu:stateRemoved',function(id,revision)
    if source ~= 65535 or type(id) ~= 'number' or type(revision) ~= 'number' then return end
    if revision < (revisions[id] or -1) then return end
    revisions[id] = revision
    observed[id] = nil
    EmoteSync.forget(id,true)
end)
RegisterNetEvent('scully_emotemenu:stateControl',function(key,value,clear)
    if source ~= 65535 or (key ~= 'isLimited' and key ~= 'allowNSFWEmotes') then return end
    if clear then value=nil end
    facade:set(key,value,false)
end)

CreateThread(function()
    while true do
        Wait(100)
        if next(pending) then
            local batch, sent = {}, {}
            for key,entry in pairs(pending) do batch[#batch+1]=entry; sent[key]=entry; pending[key]=nil end
            local ok,accepted = pcall(pr_lib.callback.await,'scully_emotemenu:publishState',false,batch)
            if not ok or not accepted then
                for key,entry in pairs(sent) do if not pending[key] then pending[key]=entry end end
                Wait(500)
            end
        end
    end
end)

CreateThread(function()
    local lastRefresh = -5000
    while true do
        Wait(1000)
        local ids,seen,changed = {},{},false
        for _,player in ipairs(GetActivePlayers()) do
            local id,ped = GetPlayerServerId(player),GetPlayerPed(player)
            if id ~= ownId() and ped ~= 0 then
                ids[#ids+1]=id; seen[id]=true
                if observed[id] ~= ped then
                    if observed[id] then EmoteSync.forget(id) end
                    observed[id]=ped; changed=true
                    TriggerEvent('scully_emotemenu:cacheStreamed',id,ped)
                end
            end
        end
        for id in pairs(observed) do
            if not seen[id] then observed[id]=nil; EmoteSync.forget(id); changed=true end
        end
        if changed or GetGameTimer()-lastRefresh >= 5000 then
            local ok,snapshot = pcall(pr_lib.callback.await,'scully_emotemenu:getStateSnapshot',false,ids)
            if ok and type(snapshot) == 'table' then
                lastRefresh=GetGameTimer()
                for identifier,record in pairs(snapshot) do
                    local id=tonumber(identifier)
                    if id and observed[id] then EmoteSync.apply(id,record) end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop',function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pr_lib.cache.clearPrefix(prefix)
end)
exports('setAllowNSFWEmotes',function(value) facade:set('allowNSFWEmotes',value == true,false) end)
exports('getEmoteState',function(key) return facade:get(key) end)
exports('setEmoteStance',function(value) return facade:set('stance',value,true) end)
return facade
