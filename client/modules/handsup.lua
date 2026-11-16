pr_lib.addKeybind({
    name = 'handsupKey',
    description = locale('hands_up'),
    defaultKey = Config.handsUpKey,
    onPressed = function()
        if Config.handsUpIsToggle and PlayerState.handsup then PlayerState.handsup = false return end
        if PlayerState.isLimited then return end
        if GetVehiclePedIsEntering(pr_lib.cache.ped) ~= 0 then return end

        local onBike = false

        if pr_lib.cache.vehicle then
            local model = GetEntityModel(pr_lib.cache.vehicle)

            onBike = IsThisModelABike(model)
        end

        pr_lib.requestAnimDict('random@mugging3')
        TaskPlayAnim(pr_lib.cache.ped, 'random@mugging3', 'handsup_standing_base', 8.0, 8.0, -1, 50, 0, false, onBike and 4127 or false, false)

        PlayerState.handsup = true

        local needsReset = false
        CreateThread(function()
            while PlayerState.handsup do
                Wait(0)

                if pr_lib.cache.vehicle then
                    DisableControlAction(0, 59, true)
                end

                DisableControlAction(0, 25, true)
                DisablePlayerFiring(pr_lib.cache.playerId, true)

                if IsPedRagdoll(pr_lib.cache.ped) then needsReset = true end

                if (Config.handsUpIsToggle and not IsEntityPlayingAnim(pr_lib.cache.ped, 'random@mugging3', 'handsup_standing_base', 3)) or (needsReset and not IsPedRagdoll(pr_lib.cache.ped)) then
                    TaskPlayAnim(pr_lib.cache.ped, 'random@mugging3', 'handsup_standing_base', 8.0, 8.0, -1, 50, 0, false, onBike and 4127 or false, false)
                    needsReset = false
                end
            end

            if Config.handsUpIsToggle then
                StopAnimTask(pr_lib.cache.ped, 'random@mugging3', 'handsup_standing_base', 8.0)
                RemoveAnimDict('random@mugging3')
            end
        end)
    end,
    onReleased = not Config.handsUpIsToggle and function()
        if PlayerState.isLimited then return end
        if not PlayerState.handsup then return end

        StopAnimTask(pr_lib.cache.ped, 'random@mugging3', 'handsup_standing_base', 8.0)
        RemoveAnimDict('random@mugging3')

        PlayerState.handsup = false
    end
})
