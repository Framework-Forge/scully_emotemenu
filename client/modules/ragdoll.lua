local IsPedOnFoot = IsPedOnFoot
local SetPedToRagdoll = SetPedToRagdoll

local isRagdoll = false

pr_lib.addKeybind({
    name = 'ragdollKey',
    description = locale('ragdoll'),
    defaultKey = Config.ragdollKey,
    onPressed = function()
        if PlayerState.isLimited or PlayerState.isInEmote then return end

        isRagdoll = not isRagdoll

        while isRagdoll do
            Wait(0)

            if PlayerState.isLimited then
                isRagdoll = false
                break
            end

            if IsPedOnFoot(pr_lib.cache.ped) then
                SetPedToRagdoll(pr_lib.cache.ped, 1000, 1000, 0, true, true, false)
            end
        end
    end
})