locale = pr_lib.locale()

KVP = pr_lib.load('client.modules.kvp')
Utils = pr_lib.load('shared.modules.utils')
Config = pr_lib.load('shared.data.config')
Walks = pr_lib.load('shared.data.walks')
Scenarios = pr_lib.load('shared.data.scenarios')
Expressions = pr_lib.load('shared.data.expressions')
Emotes = {
    pr_lib.load('shared.data.emotes.general_emotes'),
    pr_lib.load('shared.data.emotes.prop_emotes'),
    pr_lib.load('shared.data.emotes.consumable_emotes'),
    pr_lib.load('shared.data.emotes.dance_emotes'),
    pr_lib.load('shared.data.emotes.synchronized_emotes'),
    pr_lib.load('shared.data.emotes.synchronized_dance_emotes'),
    pr_lib.load('shared.data.emotes.animal_emotes')
}
ExitEmotes = pr_lib.load('shared.data.emotes.exit_emotes')

EmoteBinds = KVP.getTable('keybinds')
PlayerState = pr_lib.load('client.modules.state')

local pedTypes = pr_lib.load('client.data.ped_types')
local scenarioModels = pr_lib.load('client.data.scenario_models')
local placement = pr_lib.load('client.modules.placement')
local keybinds = {}
local registeredEmotes = {}
local pedProps = {}
local pedPtfx = {}
pr_lib.cache.set('scully_emotemenu:props',pedProps)
pr_lib.cache.set('scully_emotemenu:particles',pedPtfx)

---Check if the player is in an emote
---@return boolean
function IsInEmote()
    return PlayerState.isInEmote
end
exports('isInEmote', IsInEmote)

---Get the last emote a player used
---@return table?, number?
function GetLastEmote()
    if not PlayerState.lastEmote then return end

    return PlayerState.lastEmote[1], PlayerState.lastEmote[2]
end
exports('getLastEmote', GetLastEmote)

---Play an emote or scenario
---@param data table
---@param variation? number
function PlayEmote(data, variation)
    if PlayerState.isLimited then return end

    if data.Synchronized and not data.StartSynchronized then
        local coords = GetEntityCoords(pr_lib.cache.ped)
        local targetId = pr_lib.getClosestPlayer(coords, 3.0, false)

        if not targetId then
            Utils.notify('error', locale('no_players_nearby'))
            return
        end

        local otherEmote

        for i = 1, #Emotes do
            local emotes = Emotes[i]

            for k = 1, #emotes.options do
                local emote = emotes.options[k]

                if emote.Command == data.Options.Shared.OtherEmote then
                    otherEmote = emote
                    break
                end
            end

            if otherEmote then break end
        end

        if not otherEmote then
            Utils.notify('error', locale('not_valid_emote'))
            return
        end

        TriggerServerEvent('scully_emotemenu:requestSynchronizedEmote', GetPlayerServerId(targetId), data, otherEmote)
        return
    end

    if data.PedTypes then
        if IsPedHuman(pr_lib.cache.ped) then
            Utils.notify('error', locale('not_valid_ped'))
            return
        end

        local isValid = false
        local model = GetEntityModel(pr_lib.cache.ped)

        for i = 1, #data.PedTypes do
            local allowed = pedTypes[data.PedTypes[i]]
            local found = pr_lib.table.contains(allowed, model)

            if found then
                isValid = true
                break
            end
        end

        if not isValid then
            Utils.notify('error', locale('not_valid_ped'))
            return
        end
    end

    if not data.PedTypes and not IsPedHuman(pr_lib.cache.ped) then
        Utils.notify('error', locale('not_valid_ped'))
        return
    end

    if Config.enableWeaponBlock and IsPedArmed(pr_lib.cache.ped, 7) then
        Utils.notify('error', locale('not_with_weapon'))
        return
    end

    if Config.enableAimShootBlock then
        CreateThread(function()
            while PlayerState.isInEmote do
                Wait(0)

                DisableControlAction(0, 25, true)
                DisablePlayerFiring(pr_lib.cache.playerId, true)
            end

            CancelEmote()
        end)
    end

    local duration, movementFlag = nil, pr_lib.cache.vehicle and 51 or 0

    if not Config.enableEmotesInVehicles and pr_lib.cache.vehicle then
        Utils.notify('error', locale('not_in_vehicle'))
        return
    end

    local gameTimer = GetGameTimer()
    local emoteCooldown = PlayerState.emoteCooldown

    if emoteCooldown and (gameTimer - emoteCooldown) < Config.emoteCooldown then return end

    PlayerState:set('emoteCooldown', gameTimer, true)
    PlayerState:set('emoteProps', nil, true)
    PlayerState:set('emotePtfx', false, true)

    if data.Scenario then
        PlayScenario(data.Scenario)
        return
    end

    if Config.enableEmotePlacement and data.Placement and not data.Advanced then
        pr_lib.hideMenu()
        placement.start(data)
        return
    end

    local dictionaryName, animationName = data.Dictionary, data.Animation

    if type(dictionaryName) == 'table' and type(animationName) == 'table' then
        local randomIndex = math.random(1, #animationName)

        dictionaryName = dictionaryName[randomIndex]
        animationName = animationName[randomIndex]
    end

    local isValid = pr_lib.requestAnimDict(dictionaryName)

    if not isValid then
        Utils.notify('error', locale('not_valid_emote'))
        return
    end

    if data.NSFW and Config.enableNSFWEmotes == 'limited' and not PlayerState.allowNSFWEmotes then
        Utils.notify('error', locale('nsfw_limited'))
        return
    end

    local options = data.Options

    if options then
        duration = options.Duration

        if options.Delay then Wait(options.Delay) end

        if not pr_lib.cache.vehicle and options.Flags then
            movementFlag = options.Flags.Stuck and 50 or options.Flags.Move and 51 or options.Flags.Loop and 1 or movementFlag

            if options.Flags.Loop then
                PlayerState.lastEmote = { data, variation }
            end
        end

        if options.Props then
            local props = {}

            for i = 1, #options.Props do
                local prop = options.Props[i]
                
                if variation then
                    if prop.Variations and prop.Variations[variation] then
                        prop.Variant = prop.Variations[variation]
                    end
                end

                props[i] = {
                    hash = joaat(prop.Name),
                    bone = prop.Bone,
                    placement = prop.Placement,
                    variant = prop.Variant,
                    hasPtfx = (options and options.Ptfx and options.Ptfx.AttachToProp)
                }
            end

            PlayerState:set('emoteProps', props, true)
        end

        local ptfx = options.Ptfx

        if ptfx then
            local hasAutomatedPtfx = Config.enableAutoPtfx and ptfx.Auto

            PlayerState:set('ptfx', {
                asset = ptfx.Asset,
                name = ptfx.Name,
                placement = ptfx.Placement,
                bone = ptfx.Bone,
                color = ptfx.Color,
                canHold = ptfx.CanHold
            }, true)

            if Config.ptfxKey and not hasAutomatedPtfx then
                keybinds.Ptfx:disable(false)
                Utils.notify('success', (locale('press_for_ptfx'):format(keybinds.Ptfx:getCurrentKey())))
            else
                keybinds.Ptfx:disable(true)

                if hasAutomatedPtfx then
                    PlayerState:set('emotePtfx', true, true)
                end
            end
        else
            if Config.ptfxKey then keybinds.Ptfx:disable(true) end
        end
    end

    if data.Advanced then
        local coords = data.Advanced.Coords

        TaskPlayAnimAdvanced(pr_lib.cache.ped, dictionaryName, animationName, coords.x, coords.y, coords.z, 0, 0, data.Advanced.Heading, 2.0, 2.0, duration or -1, movementFlag, 1.0, false, false)
    else
        TaskPlayAnim(pr_lib.cache.ped, dictionaryName, animationName, 2.0, 2.0, duration or -1, movementFlag, 0, false, false, false)
    end

    RemoveAnimDict(dictionaryName)

    local secondaryEmote = (options and options.SecondaryEmote)

    if secondaryEmote then
        local isSecondaryValid = pr_lib.requestAnimDict(secondaryEmote.Dictionary, 1000)

        if not isSecondaryValid then
            Utils.notify('error', locale('not_valid_emote'))
            return
        end

        TaskPlayAnim(pr_lib.cache.ped, secondaryEmote.Dictionary, secondaryEmote.Animation, 2.0, 2.0, secondaryEmote.Duration or -1, 51, 0, false, false, false)
        RemoveAnimDict(secondaryEmote.Dictionary)
    end

    PlayerState:set('isInEmote', true, true)
end
exports('playEmote', PlayEmote)

---Cancel an emote or scenario
---@param skipReset? boolean
function CancelEmote(skipReset)
    if PlayerState.isInEmote and not PlayerState.isLimited then
        :: cancelEmote ::

        local isScenario = IsPedUsingAnyScenario(pr_lib.cache.ped)

        if isScenario then SetPedShouldPlayImmediateScenarioExit(pr_lib.cache.ped) end

        DetachEntity(pr_lib.cache.ped, true, false)
        PlayerState:set('isInEmote', false, true)
        PlayerState:set('emoteProps', nil, true)
        PlayerState:set('emotePtfx', false, true)

        if Config.ptfxKey then keybinds.Ptfx:disable(true) end

        if PlayerState.inSynchronizedEmote then
            PlayerState:set('inSynchronizedEmote', nil, true)
        end

        if isScenario then
            local coords = GetEntityCoords(pr_lib.cache.ped)

            for i = 1, #scenarioModels do
                local model = scenarioModels[i]
                local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, model, false, true, true)

                if entity ~= 0 then
                    SetEntityAsMissionEntity(entity, false, true)
                    DeleteEntity(entity)
                end
            end
        end

        local exitEmoteName = (PlayerState.lastEmote and PlayerState.lastEmote[1] and PlayerState.lastEmote[1].Options and PlayerState.lastEmote[1].Options.ExitEmote)

        if not skipReset then
            PlayerState.lastEmote = nil
            
            if exitEmoteName then
                local exitEmote = ExitEmotes[exitEmoteName]

                PlayEmote(exitEmote)

                if (exitEmote and exitEmote.Options and exitEmote.Options.Duration) then
                    Wait(exitEmote.Options.Duration)
    
                    goto cancelEmote
                end
                
                return
            end
        end

        ClearPedTasks(pr_lib.cache.ped)
    end
end
exports('cancelEmote', CancelEmote)

---Play an emote by command
---@param command string
---@param variant? number
function PlayEmoteByCommand(command, variant)
    local found

    for i = 1, #Scenarios do
        local scenario = Scenarios[i]

        if scenario.Command == command then
            found = scenario
            break
        end
    end

    if not found then
        for i = 1, #Emotes do
            local emotes = Emotes[i]
    
            for k = 1, #emotes.options do
                local emote = emotes.options[k]
    
                if emote.Command == command then
                    found = emote
                    break
                end
            end
        end
    end

    if not found then
        Utils.notify('error', locale('not_valid_emote'))
        return
    end

    PlayEmote(found, variant)
end
exports('playEmoteByCommand', PlayEmoteByCommand)

---Get the players current walk style
---@return string?
function GetCurrentWalk()
    return PlayerState.walkstyle
end
exports('getCurrentWalk', GetCurrentWalk)

---Set the players current walk style
---@param name string
function SetWalk(name)
    pr_lib.requestAnimSet(name, 1000)
    SetPedMovementClipset(pr_lib.cache.ped, name, 0.2)
    RemoveAnimSet(name)

    if Config.preventWalkStyleAbuse then
        local dict = Utils.isPedMale(pr_lib.cache.ped) and 'move_m@multiplayer' or 'move_f@multiplayer'

        pr_lib.requestAnimDict(dict)
        SetPedAlternateMovementAnim(pr_lib.cache.ped, 2, dict, 'run', 0, true)
        RemoveAnimDict(dict)
    end

    KVP.update('walkstyle', name)
    PlayerState:set('walkstyle', name, true)
end
exports('setWalk', SetWalk)

---Reset the players walk style
function ResetWalk()
    ResetPedMovementClipset(pr_lib.cache.ped, 0)
    KVP.delete('walkstyle')
    PlayerState:set('walkstyle', nil, true)
end
exports('resetWalk', resetWalk)

---Set the players current walk style using the command
---@param command string
function SetWalkByCommand(command)
    local found

    for i = 1, #Walks do
        local walk = Walks[i]

        if walk.Command == command then
            found = walk
            break
        end
    end

    if not found then
        Utils.notify('error', locale('not_valid_walk'))
        return
    end

    SetWalk(found.Walk)
end
exports('setWalkByCommand', SetWalkByCommand)

---Play a scenario
---@param name string 
function PlayScenario(name)
    if pr_lib.cache.vehicle then
        Utils.notify('error', locale('no_scenarios_in_vehicle'))
        return
    end

    ClearPedTasks(pr_lib.cache.ped)
    TaskStartScenarioInPlace(pr_lib.cache.ped, name, 0, true)
    PlayerState:set('isInEmote', true, true)
end

---Get the players current expression
---@return string
function GetCurrentExpression()
    return PlayerState.expression
end
exports('getCurrentExpression', GetCurrentExpression)

---Set the players current expression
---@param name string
function SetExpression(name)
    SetFacialIdleAnimOverride(pr_lib.cache.ped, name, 0)
    KVP.update('expression', name)
    PlayerState:set('expression', name, true)
end
exports('setExpression', SetExpression)

---Reset the players expression
function ResetExpression()
    ClearFacialIdleAnimOverride(pr_lib.cache.ped)
    KVP.delete('expression')
    PlayerState:set('expression', nil, true)
end
exports('resetExpression', ResetExpression)

---Set the players current expression using the command
---@param command string
function SetExpressionByCommand(command)
    local found

    for i = 1, #Expressions do
        local expression = Expressions[i]

        if expression.Command == command then
            found = expression
            break
        end
    end

    if not found then
        Utils.notify('error', locale('not_valid_expression'))
        return
    end

    SetExpression(found.Expression)
end
exports('setExpressionByCommand', SetExpressionByCommand)

---Register emotes to be used within external resources
---@param emote table
function RegisterEmote(emote)
    registeredEmotes[emote.Name] = emote
end
exports('registerEmote', RegisterEmote)

---Play a registered emote
---@param emote string
function PlayRegisteredEmote(emote)
    local registeredEmote = registeredEmotes[emote]

    if not registeredEmote then
        Utils.notify('error', locale('not_valid_emote'))
        return
    end

    PlayEmote(emote)
end
exports('playRegisteredEmote', PlayRegisteredEmote)

---Add an emote to the menu
---@param data table
function AddEmoteToMenu(menu, data)
    for i = 1, #Emotes do
        local emotes = Emotes[i]

        if emotes.name == menu then
            emotes.options[#emotes.options + 1] = data
            break
        end
    end

    RegisterMenu()
end
exports('addEmoteToMenu', AddEmoteToMenu)

---Add multiple emotes to the menu
---@param data table
function AddEmotesToMenu(menu, data)
    for i = 1, #Emotes do
        local emotes = Emotes[i]

        if emotes.name == menu then
            for k = 1, #data do
                emotes.options[#emotes.options + 1] = data[k]
            end
            break
        end
    end

    RegisterMenu()
end
exports('addEmotesToMenu', AddEmotesToMenu)

---Get a list of props from your current emote
---@return table?
function GetEmoteProps()
    return pedProps[pr_lib.cache.serverId]
end
exports('getEmoteProps', GetEmoteProps)

---Create props and attach them to a ped
---@param ped number
---@param data table
---@return table
function CreateProps(ped, data, isCurrent)
    local props = {}

    for i = 1, #data do
        local prop = data[i]

        if isCurrent and not isCurrent() then return props end
        if not IsModelInCdimage(prop.hash) or not IsModelValid(prop.hash) then goto nextProp end
        local ok,loaded = pcall(pr_lib.requestModel,prop.hash)
        if not ok or loaded == false then goto nextProp end
        if isCurrent and not isCurrent() then return props end
        
        local coords = GetEntityCoords(ped)
        local object = CreateObject(prop.hash, coords.x, coords.y, coords.z, false, false, false)
        
        SetEntityCollision(object, false, false)
        
        if prop.variant then SetObjectTextureVariation(object, prop.variant) end
        
        AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, prop.bone), prop.placement[1].x, prop.placement[1].y, prop.placement[1].z, prop.placement[2].x, prop.placement[2].y, prop.placement[2].z, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(prop.hash)

        props[#props+1] = {
            entity = object,
            hasPtfx = prop.hasPtfx
        }
        ::nextProp::
    end

    return props
end

---Delete props attached to a player
---@param serverId number
function DeleteProps(serverId)
    local props = pedProps[serverId]

    if not props then return end

    for i = 1, #props do
        local prop = props[i]
        
        if DoesEntityExist(prop.entity) then
            DeleteEntity(prop.entity)
        end
    end

    pedProps[serverId] = nil
end

---Creates a list for the chosen table
---@param title string
---@param tbl table
---@param command string
function CreateList(title, tbl, command)
    local list = {}

    for i = 1, #tbl do
        local entry = tbl[i]

        if entry.icon then
            list[#list + 1] = ('__**%s**__'):format(entry.name)

            for k = 1, #entry.options do
                local option = entry.options[k]

                list[#list + 1] = ('- %s (/%s %s)'):format(option.Label, command, option.Command)
            end

            list[#list + 1] = '\n'
        else
            list[i] = ('- %s (/%s %s)'):format(entry.Label, command, entry.Command)
        end
    end

    list = table.concat(list, '\n')

    pr_lib.alertDialog({
        header = title,
        content = list,
        centered = true,
        size = 'lg',
        overflow = true,
        labels = { cancel = '', confirm = locale('close') }
    })
end

---Toggle player limitations
---@param limited boolean
function SetLimitation(limited)
    PlayerState:set('isLimited', limited, true)
end
exports('setLimitation', SetLimitation)

---Check if the player is currently limited
---@return boolean
function IsLimited()
    return PlayerState.isLimited
end
exports('isLimited', IsLimited)

local IsControlJustPressed = IsControlJustPressed

RegisterNetEvent('scully_emotemenu:synchronizedEmoteRequest', function(sender, senderData, targetData)
    PlaySoundFrontend(-1, 'NAV', 'HUD_AMMO_SHOP_SOUNDSET', false)
    pr_lib.showTextUI(locale('accept_deny', targetData.Label))

    while true do
        Wait(0)
        if IsControlJustPressed(0, 246) then
            pr_lib.hideTextUI()
            TriggerServerEvent('scully_emotemenu:synchronizedEmoteResponse', sender, senderData, targetData)
            break
        elseif IsControlJustPressed(0, 306) then
            pr_lib.hideTextUI()
            break
        end
    end
end)

RegisterNetEvent('scully_emotemenu:targetStartSynchronizedEmote', function(sender, senderData, targetData)
    local isValid = pr_lib.requestAnimDict(targetData.Dictionary)

    if not isValid then
        Utils.notify('error', locale('not_valid_emote'))
        return
    end

    if targetData.Options.Shared.Attach and not senderData.Options.Shared.Attach then
        local senderId = GetPlayerFromServerId(sender)
        local senderPed = GetPlayerPed(senderId)
        local bone = targetData.Options.Shared.Bone or -1
        local placement = targetData.Options.Shared.Placement
        local xP, yP, zP, xR, yR, zR = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

        if placement then
            xP, yP, zP, xR, yR, zR = placement[1].x, placement[1].y, placement[1].z, placement[2].x, placement[2].y, placement[2].z
        end

        AttachEntityToEntity(pr_lib.cache.ped, senderPed, GetPedBoneIndex(senderPed, bone), xP, yP, zP, xR, yR, zR, false, false, false, true, 1, true)
    end

    targetData.StartSynchronized = true

    PlayEmote(targetData)
    PlayerState:set('inSynchronizedEmote', sender, true)
end)

RegisterNetEvent('scully_emotemenu:senderStartSynchronizedEmote', function(target, senderData)
    local isValid = pr_lib.requestAnimDict(senderData.Dictionary)

    if not isValid then
        Utils.notify('error', locale('not_valid_emote'))
        return
    end

    local targetId = GetPlayerFromServerId(target)
    local targetPed = GetPlayerPed(targetId)
    local frontOffset, sideOffset, heightOffset, headingOffset = 1.0, 0.0, 0.0, 180.1

    if senderData.Options.Shared.FrontOffset then
        frontOffset = senderData.Options.Shared.FrontOffset + 0.0
    end

    if senderData.Options.Shared.SideOffset then
        sideOffset = senderData.Options.Shared.SideOffset + 0.0
    end

    if senderData.Options.Shared.HeightOffset then
        heightOffset = senderData.Options.Shared.HeightOffset + 0.0
    end

    if senderData.Options.Shared.HeadingOffset then
        headingOffset = senderData.Options.Shared.HeadingOffset + 0.0
    end

    if senderData.Options.Shared.Attach then
        local bone = senderData.Options.Shared.Bone or -1
        local placement = senderData.Options.Shared.Placement
        local xP, yP, zP, xR, yR, zR = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

        if placement then
            xP, yP, zP, xR, yR, zR = placement[1].x, placement[1].y, placement[1].z, placement[2].x, placement[2].y, placement[2].z
        end

        AttachEntityToEntity(pr_lib.cache.ped, targetPed, GetPedBoneIndex(targetPed, bone), xP, yP, zP, xR, yR, zR, false, false, false, true, 1, true)
    end

    local targetCoords = GetOffsetFromEntityInWorldCoords(targetPed, sideOffset, frontOffset, heightOffset)
    local targetHeading = GetEntityHeading(targetPed)

    SetEntityHeading(pr_lib.cache.ped, targetHeading - headingOffset)
    SetEntityCoordsNoOffset(pr_lib.cache.ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)

    senderData.StartSynchronized = true

    PlayEmote(senderData)
    PlayerState:set('inSynchronizedEmote', target, true)
end)

RegisterNetEvent('scully_emotemenu:toggleMenu', ToggleMenu)
RegisterNetEvent('scully_emotemenu:closeMenu', CloseMenu)
RegisterNetEvent('scully_emotemenu:addEmoteMenuOption', AddEmoteMenuOption)
RegisterNetEvent('scully_emotemenu:playEmote', PlayEmote)
RegisterNetEvent('scully_emotemenu:cancelEmote', CancelEmote)
RegisterNetEvent('scully_emotemenu:playEmoteByCommand', PlayEmoteByCommand)
RegisterNetEvent('scully_emotemenu:setWalk', SetWalk)
RegisterNetEvent('scully_emotemenu:resetWalk', ResetWalk)
RegisterNetEvent('scully_emotemenu:setWalkByCommand', SetWalkByCommand)
RegisterNetEvent('scully_emotemenu:setExpression', SetExpression)
RegisterNetEvent('scully_emotemenu:resetExpression', ResetExpression)
RegisterNetEvent('scully_emotemenu:setExpressionByCommand', SetExpressionByCommand)
RegisterNetEvent('scully_emotemenu:registerEmote', RegisterEmote)
RegisterNetEvent('scully_emotemenu:playRegisteredEmote', PlayRegisteredEmote)
RegisterNetEvent('scully_emotemenu:setLimitation', SetLimitation)
RegisterNetEvent('scully_emotemenu:addEmoteToMenu', AddEmoteToMenu)
RegisterNetEvent('scully_emotemenu:addEmotesToMenu', AddEmotesToMenu)

local visualGeneration, rebuildProps, visualWorkers = {}, {}, {}
pr_lib.cache.set('scully_emotemenu:visualGeneration',visualGeneration)
pr_lib.cache.set('scully_emotemenu:rebuildProps',rebuildProps)
pr_lib.cache.set('scully_emotemenu:visualWorkers',visualWorkers)

local function stopEffect(id)
    if pedPtfx[id] then StopParticleFxLooped(pedPtfx[id],false); pedPtfx[id]=nil end
end
local function clearVisuals(id)
    visualGeneration[id]=(visualGeneration[id] or 0)+1
    rebuildProps[id]=nil
    stopEffect(id)
    DeleteProps(id)
end
local function renderVisuals(id,generation,replaceProps)
    local player=GetPlayerFromServerId(id)
    if player == -1 then clearVisuals(id); return end
    local ped=GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then clearVisuals(id); return end
    stopEffect(id)
    if replaceProps then
        DeleteProps(id)
        local props=EmoteSync.get(id,'emoteProps')
        if props then
            local created=CreateProps(ped,props,function() return visualGeneration[id] == generation end)
            if visualGeneration[id] ~= generation then
                for _,prop in ipairs(created) do if DoesEntityExist(prop.entity) then DeleteEntity(prop.entity) end end
                return
            end
            pedProps[id]=created
        end
    end
    local ptfx=EmoteSync.get(id,'ptfx')
    if not EmoteSync.get(id,'emotePtfx') or not ptfx then return end
    local target=ped
    for _,prop in ipairs(pedProps[id] or {}) do
        if prop.hasPtfx then target=prop.entity; break end
    end
    local ok,loaded=pcall(pr_lib.requestNamedPtfxAsset,ptfx.asset)
    if not ok or loaded == false then return end
    if visualGeneration[id] ~= generation or not DoesEntityExist(target) then RemoveNamedPtfxAsset(ptfx.asset); return end
    local bone=ptfx.bone and GetPedBoneIndex(ped,ptfx.bone) or GetEntityBoneIndexByName(target,'VFX')
    UseParticleFxAsset(ptfx.asset)
    local effect=StartParticleFxLoopedOnEntityBone(ptfx.name,target,ptfx.placement[1].x,ptfx.placement[1].y,ptfx.placement[1].z,ptfx.placement[2].x,ptfx.placement[2].y,ptfx.placement[2].z,bone,ptfx.placement[3]+0.0,false,false,false)
    local tint=ptfx.color
    if tint then
        if tint[1] then tint=tint[math.random(1,#tint)] end
        SetParticleFxLoopedAlpha(effect,tint.A)
        SetParticleFxLoopedColour(effect,tint.R/255,tint.G/255,tint.B/255,false)
    end
    RemoveNamedPtfxAsset(ptfx.asset)
    pedPtfx[id]=effect
end
local function queueVisuals(id,replaceProps)
    visualGeneration[id]=(visualGeneration[id] or 0)+1
    if replaceProps then rebuildProps[id]=true end
    local generation=visualGeneration[id]
    if visualWorkers[id] then return end
    visualWorkers[id]=true
    CreateThread(function()
        while true do
            Wait(0)
            generation=visualGeneration[id]
            local replace=rebuildProps[id]; rebuildProps[id]=nil
            local ok,err=pcall(renderVisuals,id,generation,replace)
            if not ok then clearVisuals(id); print(('[scully_emotemenu] cache visuals: %s'):format(tostring(err))) end
            if not ok or generation == visualGeneration[id] then break end
        end
        visualWorkers[id]=nil
    end)
end
local function partnerCancelled(id)
    if PlayerState.inSynchronizedEmote == id then
        Utils.notify('error',locale('emote_cancelled'))
        CancelEmote()
    end
end

AddEventHandler('scully_emotemenu:cacheChanged',function(id,key,value)
    if key == 'emoteProps' or key == 'emotePtfx' or key == 'ptfx' then
        queueVisuals(id,key == 'emoteProps')
    elseif key == 'inSynchronizedEmote' and not value then
        partnerCancelled(id)
    end
end)
AddEventHandler('scully_emotemenu:cacheStreamed',function(id) queueVisuals(id,true) end)
AddEventHandler('scully_emotemenu:cacheRemoved',function(id) clearVisuals(id); partnerCancelled(id) end)
pr_lib.onCache('ped',function()
    PlayerState:set('isInEmote',false,true)
    PlayerState:set('emoteProps',nil,true)
    PlayerState:set('emotePtfx',false,true)
    PlayerState:set('inSynchronizedEmote',nil,true)
    PlayerState:set('handsup',false,true)
end)
-- Compatibility for integrations emitting the previous disconnect event.
RegisterNetEvent('onPlayerDropped',function(id) clearVisuals(id); partnerCancelled(id) end)

AddEventHandler('onResourceStop',function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(pedProps) do clearVisuals(id) end
    for id in pairs(pedPtfx) do clearVisuals(id) end
    DetachEntity(pr_lib.cache.ped,true,false)
    ClearPedTasks(pr_lib.cache.ped)
end)

if Config.emoteCommands then
    for i = 1, #Config.emoteCommands do
        Utils.addCommand(Config.emoteCommands[i], {
            help = locale('emote_command_help'),
            params = {
                { name = locale('emote_command_param1_name'), help = locale('emote_command_param1_help') },
                { name = locale('emote_command_param2_name'), help = locale('emote_command_param2_help') }
            }
        }, function(source, args, raw)
            local param1 = args[1]

            if not param1 then
                Utils.notify('error', locale('not_valid_emote'))
                return
            end

            local emoteName = param1:lower()

            if emoteName == 'c' then
                CancelEmote()
                return
            end

            if emoteName == 'l' then
                CreateList(locale('emotes'), Emotes, Config.emoteCommands[1])
                return
            end

            local variant
            local param2 = args[2]

            if param2 then
                local index = tonumber(param2)

                if index then variant = index end
            end

            PlayEmoteByCommand(emoteName, variant)
        end)
    end
end

if Config.walkCommands then
    for i = 1, #Config.walkCommands do
        Utils.addCommand(Config.walkCommands[i], {
            help = locale('walk_command_help'),
            params = {
                { name = locale('walk_command_param1_name'), help = locale('walk_command_param1_help') }
            }
        }, function(source, args, raw)
            local param1 = args[1]

            if not param1 then
                Utils.notify('error', locale('not_valid_walk'))
                return
            end

            local walkName = param1:lower()

            if walkName == 'c' then
                ResetWalk()
                return
            end

            if walkName == 'l' then
                CreateList(locale('walking_styles'), Walks, Config.walkCommands[1])
                return
            end

            SetWalkByCommand(walkName)
        end)
    end
end

if Config.expressionCommands then
    for i = 1, #Config.expressionCommands do
        Utils.addCommand(Config.expressionCommands[i], {
            help = locale('expression_command_help'),
            params = {
                { name = locale('expression_command_param1_name'), help = locale('expression_command_param1_help') }
            }
        }, function(source, args, raw)
            local param1 = args[1]

            if not param1 then
                Utils.notify('error', locale('not_valid_expression'))
                return
            end

            local expressionName = param1:lower()

            if expressionName == 'c' then
                ResetExpression()
                return
            end

            if expressionName == 'l' then
                CreateList(locale('facial_expressions'), Expressions, Config.expressionCommands[1])
                return
            end

            SetExpressionByCommand(expressionName)
        end)
    end
end

if Config.emoteCancelKey then
    pr_lib.addKeybind({
        name = 'emoteCancelKey',
        description = locale('cancel_emote'),
        defaultKey = Config.emoteCancelKey,
        onPressed = function()
            CancelEmote()
        end
    })
end

if Config.ptfxKey then
    keybinds.Ptfx = pr_lib.addKeybind({
        name = 'ptfxKey',
        disabled = true,
        description = locale('play_ptfx'),
        defaultKey = Config.ptfxKey,
        onPressed = function()
            PlayerState:set('emotePtfx', true, true)

            if not (PlayerState.ptfx and PlayerState.ptfx.canHold) then
                PlayerState:set('emotePtfx', false, true)
            end
        end,
        onReleased = function()
            if (PlayerState.ptfx and PlayerState.ptfx.canHold) then
                PlayerState:set('emotePtfx', false, true)
            end
        end
    })
end

if Config.enableEmoteBinds then
    for i = 1, 5 do
        local index = tostring(i)
    
        pr_lib.addKeybind({
            name = ('emotebindKey-%s'):format(index),
            description = locale('emote_bind', index),
            defaultKey = '',
            onPressed = function()
                local emote = EmoteBinds[index]
    
                if emote then
                    PlayEmote(emote)
                end
            end
        })
    end
end

pr_lib.onCache('ped', function(ped)
    local walkstyle = KVP.getString('walkstyle')

    if walkstyle then
        SetWalk(walkstyle)
    end

    local expression = KVP.getString('expression')

    if expression then
        SetExpression(expression)
    end
end)

AddEventHandler('playerSpawned', function()
    Wait(1000)

    local walkstyle = KVP.getString('walkstyle')

    if walkstyle then
        SetWalk(walkstyle)
    end

    local expression = KVP.getString('expression')

    if expression then
        SetExpression(expression)
    end
end)

AddEventHandler('entityDamaged', function(entity)
    if pr_lib.cache.ped == entity then
        if not IsPedFatallyInjured(pr_lib.cache.ped) then return end

        CancelEmote()
    end
end)

local openingDoor = false
local IsPedOpeningADoor = IsPedOpeningADoor

AddEventHandler('CEventOpenDoor', function()
    if not PlayerState.isInEmote then return end
    if openingDoor then return end

    openingDoor = true

    while IsPedOpeningADoor(pr_lib.cache.ped) do
        Wait(100)
    end

    openingDoor = false

    local lastEmote = PlayerState.lastEmote

    if lastEmote then
        CancelEmote(true)
        Wait(10)
        PlayEmote(lastEmote[1], lastEmote[2])
    end
end)

local hitTimeout, hittingPed = 500, false

AddEventHandler('CEventPlayerCollisionWithPed', function()
    if not PlayerState.isInEmote then return end

    if hittingPed then
        hitTimeout = 500
        return
    end

    hitTimeout, hittingPed = 500, true

    while hitTimeout > 0 do
        Wait(100)

        hitTimeout = hitTimeout - 100
    end

    local lastEmote = PlayerState.lastEmote

    if lastEmote then
        hitTimeout, hittingPed = 500, false

        CancelEmote(true)
        Wait(10)
        PlayEmote(lastEmote[1], lastEmote[2])
    end
end)

if Config.handsUpKey ~= '' then pr_lib.load('client.modules.handsup') end
if Config.stanceKey ~= '' then pr_lib.load('client.modules.stance') end
if Config.pointKey ~= '' then pr_lib.load('client.modules.point') end
if Config.ragdollKey ~= '' then pr_lib.load('client.modules.ragdoll') end
