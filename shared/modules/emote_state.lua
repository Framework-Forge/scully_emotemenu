-- Cache transport contract. Only bounded cosmetic state crosses the network.
local contract = {}
contract.keys = {
    emoteProps=true, emotePtfx=true, ptfx=true, isInEmote=true,
    inSynchronizedEmote=true, walkstyle=true, expression=true, stance=true,
    handsup=true, isLimited=true, allowNSFWEmotes=true,
}

local function finite(value, limit)
    return type(value) == 'number' and value == value and math.abs(value) <= limit
end
local function vector(value, limit)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' then return nil end
    if not finite(value.x, limit) or not finite(value.y, limit) or not finite(value.z, limit) then return nil end
    return {x=value.x, y=value.y, z=value.z}
end
local function name(value)
    return type(value) == 'string' and #value > 0 and #value <= 100 and not value:find('%c')
end
local function placement(value, scale)
    if type(value) ~= 'table' then return nil end
    local offset, rotation = vector(value[1], 20), vector(value[2], 3600)
    if not offset or not rotation then return nil end
    local size=value[3] or 1.0
    if scale and (not finite(size, 20) or size <= 0) then return nil end
    return {offset, rotation, scale and size or nil}
end
local function color(value)
    if type(value) ~= 'table' then return nil end
    if value[1] then
        if #value > 16 then return nil end
        local result = {}
        for i=1,#value do result[i] = color(value[i]); if not result[i] then return nil end end
        return result
    end
    if not finite(value.R,255) or not finite(value.G,255) or not finite(value.B,255) or not finite(value.A,255) then return nil end
    return {R=value.R,G=value.G,B=value.B,A=value.A}
end

function contract.normalize(key, value)
    if not contract.keys[key] then return false end
    if value == nil then return true, nil end
    if key == 'emoteProps' then
        if type(value) ~= 'table' or #value > 8 then return false end
        local props = {}
        for i=1,#value do
            local prop = value[i]
            if type(prop) ~= 'table' or not finite(prop.hash,4294967295) or not finite(prop.bone,65535) then return false end
            local transform = placement(prop.placement)
            if not transform or (prop.variant ~= nil and not finite(prop.variant,255)) then return false end
            props[i] = {hash=prop.hash,bone=prop.bone,placement=transform,variant=prop.variant,hasPtfx=prop.hasPtfx == true}
        end
        return true, props
    elseif key == 'ptfx' then
        if type(value) ~= 'table' or not name(value.asset) or not name(value.name) then return false end
        local transform = placement(value.placement,true)
        if not transform or (value.bone ~= nil and not finite(value.bone,65535)) then return false end
        local tint = value.color and color(value.color)
        if value.color and not tint then return false end
        return true, {asset=value.asset,name=value.name,placement=transform,bone=value.bone,color=tint,canHold=value.canHold == true}
    elseif key == 'walkstyle' or key == 'expression' then
        return name(value) == true, value
    elseif key == 'stance' then
        return value == 0 or value == 1 or value == 2, value
    elseif key == 'inSynchronizedEmote' then
        return finite(value,65535) and value > 0 and value % 1 == 0, value
    end
    return type(value) == 'boolean', value
end
function contract.equal(a,b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for key,value in pairs(a) do if not contract.equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
return contract
