local IsPedFalling = IsPedFalling
local IsPedJumping = IsPedJumping
local IsAimCamActive = IsAimCamActive
local SetPedMaxMoveBlendRatio = SetPedMaxMoveBlendRatio
local IsPedUsingActionMode = IsPedUsingActionMode
local SetPedUsingActionMode = SetPedUsingActionMode
local SetPedCanPlayAmbientAnims = SetPedCanPlayAmbientAnims
local DisableFirstPersonCamThisFrame = DisableFirstPersonCamThisFrame

local returnStance = false
PlayerState.stance = 0

-- Disable the stance controls
local function disableStanceControls()
    DisableControlAction(0, 36, true)
    DisableControlAction(0, 26, true)
    pr_lib.disableControls:Add({36, 26})

    CreateThread(function()
        while IsDisabledControlPressed(0, 36) or IsDisabledControlPressed(0, 26) do
            Wait(0)

            pr_lib.disableControls()
        end

        pr_lib.disableControls:Remove({36, 26})
    end)
end

-- Reset stance state
local function resetStance()
    returnStance = false
    PlayerState.stance = 0
end

---Crouch loop
local function crouchLoop()
    pr_lib.requestAnimSet('move_ped_crouched')
    SetPedStealthMovement(pr_lib.cache.ped, false, 0)
    SetPedMovementClipset(pr_lib.cache.ped, 'move_ped_crouched', 1.0)
    SetPedWeaponMovementClipset(pr_lib.cache.ped, 'move_ped_crouched')
    SetPedStrafeClipset(pr_lib.cache.ped, 'move_ped_crouched_strafing')
    SetPedCanPlayAmbientAnims(pr_lib.cache.ped, false)
    SetPedCanPlayAmbientBaseAnims(pr_lib.cache.ped, false)

    CreateThread(function()
        while PlayerState.stance == 2 do
            Wait(0)

            if pr_lib.cache.vehicle then
                resetStance()
                break
            end

            if IsPedFalling(pr_lib.cache.ped) then
                resetStance()
                break
            end

            if IsPedJumping(pr_lib.cache.ped) then
                resetStance()
                break
            end

            if IsAimCamActive() then
                SetPedMaxMoveBlendRatio(pr_lib.cache.ped, 0.2)
            end

            if IsPedUsingActionMode(pr_lib.cache.ped) then
                SetPedUsingActionMode(pr_lib.cache.ped, false, -1, 'DEFAULT_ACTION')
            end

            SetPedCanPlayAmbientIdles(pr_lib.cache.ped, true, false)
        end

        local walkstyle = PlayerState.walkstyle

        if not walkstyle then
            ResetPedMovementClipset(pr_lib.cache.ped, 1.0)
        else
            pr_lib.requestAnimSet(walkstyle, 1000)
            SetPedMovementClipset(pr_lib.cache.ped, walkstyle, 1.0)
            RemoveAnimSet(walkstyle)
        end

        ResetPedWeaponMovementClipset(pr_lib.cache.ped)
        ResetPedStrafeClipset(pr_lib.cache.ped)
        SetPedMaxMoveBlendRatio(pr_lib.cache.ped, 1.0)
        SetPedCanPlayAmbientAnims(pr_lib.cache.ped, true)
        SetPedCanPlayAmbientBaseAnims(pr_lib.cache.ped, true)
        RemoveAnimSet('move_ped_crouched')
    end)
end

PlayerState:on('stance', function(value)
    if value == 0 then
        SetPedStealthMovement(pr_lib.cache.ped, false, 0)
    elseif value == 1 then
        SetPedStealthMovement(pr_lib.cache.ped, true, 0)
    elseif value == 2 then
        crouchLoop()
    end
end)

pr_lib.addKeybind({
    name = 'stanceKey',
    description = not Config.useCrouchOnly and locale('stance') or locale('crouch'),
    defaultKey = Config.stanceKey,
    onPressed = function()
        if PlayerState.isLimited or pr_lib.cache.vehicle then return end

        disableStanceControls()

        local stanceLevel = PlayerState.stance

        if returnStance then
            stanceLevel = stanceLevel - 1

            if Config.useCrouchOnly and stanceLevel == 1 then stanceLevel = 0 end
            if stanceLevel == 0 then returnStance = false end
        else
            stanceLevel = stanceLevel + 1

            if Config.useCrouchOnly and stanceLevel == 1 then stanceLevel = 2 end
            if stanceLevel == 2 then returnStance = true end
        end

        PlayerState.stance = stanceLevel
    end
})
