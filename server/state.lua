local contract = pr_lib.load('shared.modules.emote_state')
local prefix = 'scully_emotemenu:'
local watchers, subscriptions, limits = {}, {}, {}
pr_lib.cache.set(prefix .. 'watchers',watchers)
pr_lib.cache.set(prefix .. 'subscriptions',subscriptions)
pr_lib.cache.set(prefix .. 'limits',limits)
local revision = 0

local function allowed(observer,owner)
    if observer == owner then return true end
    if not GetPlayerName(observer) or not GetPlayerName(owner) then return false end
    if GetPlayerRoutingBucket(observer) ~= GetPlayerRoutingBucket(owner) then return false end
    local a,b = GetPlayerPed(observer),GetPlayerPed(owner)
    return a ~= 0 and b ~= 0 and #(GetEntityCoords(a)-GetEntityCoords(b)) <= 200
end
local function publish(owner,updates)
    local key = prefix .. 'player:' .. owner
    local previous = pr_lib.cache.get(key) or {fields={}}
    local fields = {}
    for name,value in pairs(previous.fields) do fields[name]=value end
    for _,entry in ipairs(updates) do
        if entry.clear then fields[entry.key]=nil else fields[entry.key]=entry.value end
    end
    revision=revision+1
    local record={revision=revision,fields=fields}
    pr_lib.cache.set(key,record)
    for observer in pairs(watchers[owner] or {}) do
        if allowed(observer,owner) then TriggerClientEvent('scully_emotemenu:stateUpdate',observer,owner,record) end
    end
    return true
end
pr_lib.callback.register('scully_emotemenu:publishState',function(src,batch)
    if not GetPlayerName(src) or type(batch) ~= 'table' or #batch > 11 or #batch == 0 then return false end
    local now=GetGameTimer()
    if limits[src] and now-limits[src] < 50 then return false end
    limits[src]=now
    local updates={}
    for _,entry in ipairs(batch) do
        if type(entry) ~= 'table' or not contract.keys[entry.key] then return false end
        -- NSFW eligibility is controlled by trusted server exports, not clients.
        if entry.key == 'allowNSFWEmotes' then return false end
        local value=entry.value
        if entry.clear then value=nil end
        local ok,normalized=contract.normalize(entry.key,value)
        if not ok then return false end
        updates[#updates+1]={key=entry.key,value=normalized,clear=entry.clear == true}
    end
    return publish(src,updates)
end)

pr_lib.callback.register('scully_emotemenu:getStateSnapshot',function(src,ids)
    if not GetPlayerName(src) or type(ids) ~= 'table' or #ids > 256 then return {} end
    local previous=subscriptions[src] or {}
    for owner in pairs(previous) do if watchers[owner] then watchers[owner][src]=nil end end
    local subscribed,result={},{}
    for _,owner in ipairs(ids) do
        if type(owner) == 'number' and owner % 1 == 0 and owner ~= src and allowed(src,owner) then
            subscribed[owner]=true
            watchers[owner]=watchers[owner] or {}
            watchers[owner][src]=true
            result[owner]=pr_lib.cache.get(prefix .. 'player:' .. owner) or {revision=0,fields={}}
        end
    end
    subscriptions[src]=subscribed
    return result
end)

local function control(src,key,value)
    src=tonumber(src)
    if not src or not GetPlayerName(src) or (key ~= 'isLimited' and key ~= 'allowNSFWEmotes') or type(value) ~= 'boolean' then return false end
    publish(src,{{key=key,value=value}})
    TriggerClientEvent('scully_emotemenu:stateControl',src,key,value,false)
    return true
end
exports('setPlayerLimitation',function(src,value) return control(src,'isLimited',value) end)
exports('setPlayerAllowNSFWEmotes',function(src,value) return control(src,'allowNSFWEmotes',value) end)
exports('getPlayerEmoteState',function(src)
    local record=pr_lib.cache.get(prefix .. 'player:' .. tostring(src))
    if not record then return nil end
    local copy={}
    for key,value in pairs(record.fields) do
        local ok,normalized=contract.normalize(key,value)
        if ok then copy[key]=normalized end
    end
    return copy
end)

AddEventHandler('playerDropped',function()
    local src=source
    revision=revision+1
    for observer in pairs(watchers[src] or {}) do TriggerClientEvent('scully_emotemenu:stateRemoved',observer,src,revision) end
    for owner in pairs(subscriptions[src] or {}) do if watchers[owner] then watchers[owner][src]=nil end end
    watchers[src],subscriptions[src],limits[src]=nil,nil,nil
    pr_lib.cache.clear(prefix .. 'player:' .. src)
end)
AddEventHandler('onResourceStop',function(resource)
    if resource == GetCurrentResourceName() then pr_lib.cache.clearPrefix(prefix) end
end)
