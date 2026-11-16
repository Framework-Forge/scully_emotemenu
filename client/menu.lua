local preview = pr_lib.load('client.modules.preview')

---Close the emote menu
function CloseMenu()
    local currentMenu = pr_lib.getOpenContextMenu()

    if not currentMenu or not string.find(currentMenu, 'emotemenu_') then return end

    pr_lib.hideContext()
end
exports('closeMenu', CloseMenu)

---Toggle the emote menu
function ToggleMenu()
    if PlayerState.isLimited then return end

    local currentMenu = pr_lib.getOpenContextMenu()

    if not currentMenu then
        pr_lib.showContext('emotemenu_main_menu')
    else
        CloseMenu()
    end
end
exports('toggleMenu', ToggleMenu)

local function openBindsContext()
    local bindMenuOptions = {}

    for i = 1, 5 do
        local emote = EmoteBinds[tostring(i)]
        if emote then
            bindMenuOptions[i] = {
                title = ("%d. %s"):format(i, emote.Label),
                description = locale('delete_bind'),
                icon = 'keyboard',
                onSelect = function()
                    EmoteBinds[tostring(i)] = nil
                    KVP.update('keybinds', EmoteBinds)
                    Utils.notify('success', locale('bind_deleted'))
                    openBindsContext()
                end
            }
        else
            bindMenuOptions[i] = {
                title = ("%d. %s"):format(i, locale('none')),
                description = locale('new_bind'),
                icon = 'keyboard',
                onSelect = function()
                    local query = pr_lib.inputDialog(locale('new_bind'), { locale('emote_command_to_bind') })
                    if not query or not query[1] or query[1] == "" then
                        pr_lib.showContext('emotemenu_submenu_binds')
                        return
                    end

                    local commandInput = string.lower(query[1])
                    local bindEmote

                    for catIdx = 1, #Emotes do
                        local category = Emotes[catIdx]
                        for optIdx = 1, #category.options do
                            local e = category.options[optIdx]
                            if e.Command == commandInput then
                                bindEmote = e
                                break
                            end
                        end
                        if bindEmote then break end
                    end

                    if not bindEmote then
                        Utils.notify('error', locale('not_valid_emote'))
                        openBindsContext()
                        return
                    end

                    if bindEmote.BlockBinding then
                        Utils.notify('error', locale('bind_blocked'))
                        openBindsContext()
                        return
                    end

                    EmoteBinds[tostring(i)] = bindEmote
                    KVP.update('keybinds', EmoteBinds)
                    Utils.notify('success', locale('bind_saved'))
                    openBindsContext()
                end
            }
        end
    end

    pr_lib.registerContext({
        id = 'emotemenu_submenu_binds',
        title = locale('keybinds'),
        menu = 'emotemenu_submenu_emotes',
        options = bindMenuOptions
    })

    pr_lib.showContext('emotemenu_submenu_binds')
end

---Register the emote menu
function RegisterMenu()
    -- Submenu: Walking Styles
    local walkOptions = {}
    local walkCmd = Config.walkCommands[1] or 'walk'
    for k = 1, #Walks do
        local walk = Walks[k]
        walkOptions[#walkOptions + 1] = {
            title = walk.Label,
            description = ('/%s %s'):format(walkCmd, walk.Command),
            icon = 'person-walking',
            onSelect = function()
                SetWalk(walk.Walk)
            end
        }
    end
    pr_lib.registerContext({
        id = 'emotemenu_walks',
        title = locale('walking_styles'),
        menu = 'emotemenu_main_menu',
        options = walkOptions
    })

    -- Submenu: Scenarios
    local scenarioOptions = {}
    local emoteCmd = Config.emoteCommands[1] or 'e'
    for k = 1, #Scenarios do
        local scenario = Scenarios[k]
        scenarioOptions[#scenarioOptions + 1] = {
            title = scenario.Label,
            description = ('/%s %s'):format(emoteCmd, scenario.Command),
            icon = 'person-walking-with-cane',
            onSelect = function()
                PlayEmote(scenario)
            end
        }
    end
    pr_lib.registerContext({
        id = 'emotemenu_scenarios',
        title = locale('scenarios'),
        menu = 'emotemenu_main_menu',
        options = scenarioOptions
    })

    -- Submenu: Expressions
    local expressionOptions = {}
    local exprCmd = Config.expressionCommands[1] or 'mood'
    for k = 1, #Expressions do
        local expression = Expressions[k]
        expressionOptions[#expressionOptions + 1] = {
            title = expression.Label,
            description = ('/%s %s'):format(exprCmd, expression.Command),
            icon = 'face-angry',
            onSelect = function()
                SetExpression(expression.Expression)
            end
        }
    end
    pr_lib.registerContext({
        id = 'emotemenu_expressions',
        title = locale('facial_expressions'),
        menu = 'emotemenu_main_menu',
        options = expressionOptions
    })

    -- Submenu: Cancel
    pr_lib.registerContext({
        id = 'emotemenu_cancel',
        title = locale('cancel'),
        menu = 'emotemenu_main_menu',
        options = {
            {
                title = locale('emote'),
                description = locale('cancel_your_emote'),
                icon = 'ban',
                onSelect = CancelEmote
            },
            {
                title = locale('walk_style'),
                description = locale('reset_walk_style'),
                icon = 'ban',
                onSelect = ResetWalk
            },
            {
                title = locale('expression'),
                description = locale('reset_your_expression'),
                icon = 'ban',
                onSelect = ResetExpression
            },
            {
                title = locale('all'),
                description = locale('cancel_reset_everything'),
                icon = 'ban',
                onSelect = function()
                    CancelEmote()
                    ResetWalk()
                    ResetExpression()
                end
            }
        }
    })

    -- Main Menu Options
    local mainMenuOptions = {
        { title = locale('emote_options'), description = locale('open_emote_options'), icon = 'person', menu = 'emotemenu_submenu_emotes', arrow = true },
        { title = locale('walking_styles'), icon = 'person-walking', menu = 'emotemenu_walks', arrow = true },
        { title = locale('scenarios'), icon = 'person-walking-with-cane', menu = 'emotemenu_scenarios', arrow = true },
        { title = locale('facial_expressions'), icon = 'face-angry', menu = 'emotemenu_expressions', arrow = true },
        { title = locale('cancel'), icon = 'ban', menu = 'emotemenu_cancel', arrow = true }
    }

    pr_lib.registerContext({
        id = 'emotemenu_main_menu',
        title = locale('emote_menu'),
        position = Config.menuPosition,
        options = mainMenuOptions
    })

    -- Filter Emotes
    Emotes = Utils.filterTable(Emotes, function(tbl, index)
        local option = tbl[index]
        local keepOption = true

        if option.name == 'Consumable Emotes' and not Config.enableConsumableEmotes then
            keepOption = false
        elseif option.name == 'Synchronized Emotes' and not Config.enableSynchronizedEmotes then
            keepOption = false
        elseif option.name == 'Synchronized Dance Emotes' and not Config.enableSynchronizedEmotes then
            keepOption = false
        elseif option.name == 'Animal Emotes' and not Config.enableAnimalEmotes then
            keepOption = false
        end

        return keepOption
    end)

    local emoteCategoryOptions = {
        {
            title = locale('search'),
            description = locale('search_for_emotes'),
            icon = 'magnifying-glass',
            onSelect = function()
                local query = pr_lib.inputDialog(locale('search'), { locale('emote') })

                if not query or not query[1] or query[1] == "" then
                    pr_lib.showContext('emotemenu_submenu_emotes')
                    return
                end

                local searchTerm = string.lower(query[1])
                local searchResultsOptions = {}

                for i = 1, #Emotes do
                    local category = Emotes[i]
                    local foundCategoryOptions = {}

                    for k = 1, #category.options do
                        local emote = category.options[k]

                        if not emote.Hide and (string.find(string.lower(emote.Label), searchTerm) or string.find(string.lower(emote.Command), searchTerm)) then
                            foundCategoryOptions[#foundCategoryOptions + 1] = {
                                title = emote.Label,
                                description = ('/%s %s'):format(emoteCmd, emote.Command),
                                onSelect = function()
                                    if Config.enableEmotePreview and IsControlPressed(0, 38) then
                                        preview.showEmote(emote)
                                        return
                                    end
                                    PlayEmote(emote)
                                end
                            }
                        end
                    end

                    if #foundCategoryOptions > 0 then
                        local searchCatId = 'emotemenu_search_cat_' .. i
                        pr_lib.registerContext({
                            id = searchCatId,
                            title = category.name,
                            menu = 'emotemenu_submenu_emotes_search',
                            options = foundCategoryOptions
                        })

                        searchResultsOptions[#searchResultsOptions + 1] = {
                            title = category.name,
                            icon = category.icon or 'person',
                            menu = searchCatId,
                            arrow = true
                        }
                    end
                end

                if #searchResultsOptions == 0 then
                    Utils.notify('error', locale('not_valid_emote'))
                    pr_lib.showContext('emotemenu_submenu_emotes')
                    return
                end

                pr_lib.registerContext({
                    id = 'emotemenu_submenu_emotes_search',
                    title = locale('search_results'),
                    menu = 'emotemenu_submenu_emotes',
                    options = searchResultsOptions
                })

                pr_lib.showContext('emotemenu_submenu_emotes_search')
            end
        }
    }

    if Config.enableEmoteBinds then
        emoteCategoryOptions[#emoteCategoryOptions + 1] = {
            title = locale('keybinds'),
            description = locale('create_delete_binds'),
            icon = 'keyboard',
            onSelect = function()
                openBindsContext()
            end
        }
    end

    for i = 1, #Emotes do
        local category = Emotes[i]

        category.options = Utils.filterTable(category.options, function(tbl, index)
            local emote = tbl[index]
            local keepEmote = true

            if not DoesAnimDictExist(emote.Dictionary) then
                keepEmote = false
            elseif (emote and emote.Options and emote.Options.Props) then
                local props = emote.Options.Props
                for k = 1, #props do
                    if not IsModelValid(joaat(props[k].Name)) then
                        keepEmote = false
                        break
                    end
                end
            end

            if emote.NSFW and Config.enableNSFWEmotes == 'false' then
                keepEmote = false
            elseif emote.Gang and not Config.enableGangEmotes then
                keepEmote = false
            elseif emote.SocialMovement and not Config.enableSocialMovementEmotes then
                keepEmote = false
            end

            return keepEmote
        end)

        local categoryEmoteOptions = {}

        for k = 1, #category.options do
            local emote = category.options[k]

            if not emote.Hide then
                categoryEmoteOptions[#categoryEmoteOptions + 1] = {
                    title = emote.Label,
                    description = ('/%s %s - %s'):format(emoteCmd, emote.Command, locale('hold_to_preview')),
                    onSelect = function()
                        if Config.enableEmotePreview and IsControlPressed(0, 38) then
                            preview.showEmote(emote)
                            return
                        end
                        PlayEmote(emote)
                    end
                }
            end
        end

        local categoryMenuId = 'emotemenu_cat_' .. i
        pr_lib.registerContext({
            id = categoryMenuId,
            title = category.name,
            menu = 'emotemenu_submenu_emotes',
            options = categoryEmoteOptions
        })

        emoteCategoryOptions[#emoteCategoryOptions + 1] = {
            title = category.name,
            icon = category.icon or 'person',
            menu = categoryMenuId,
            arrow = true
        }
    end

    pr_lib.registerContext({
        id = 'emotemenu_submenu_emotes',
        title = locale('emote_options'),
        menu = 'emotemenu_main_menu',
        options = emoteCategoryOptions
    })
end

---Register the radial menu
function RegisterRadialMenu()
    local radialWalksOptions = {
        {
            label = locale('view_list'),
            icon = 'list',
            onSelect = function()
                pr_lib.showContext('emotemenu_walks')
            end
        },
        {
            label = locale('cancel'),
            icon = 'ban',
            onSelect = ResetWalk
        }
    }

    for k = 1, #Walks do
        local walk = Walks[k]
        radialWalksOptions[#radialWalksOptions + 1] = {
            label = walk.Label,
            icon = 'person-walking',
            onSelect = function()
                SetWalk(walk.Walk)
            end
        }
    end

    pr_lib.registerRadial({
        id = 'emotemenu_walks',
        items = radialWalksOptions
    })

    local radialExpressionsOptions = {
        {
            label = locale('view_list'),
            icon = 'list',
            onSelect = function()
                pr_lib.showContext('emotemenu_expressions')
            end
        },
        {
            label = locale('cancel'),
            icon = 'ban',
            onSelect = ResetExpression
        }
    }

    for k = 1, #Expressions do
        local expression = Expressions[k]
        radialExpressionsOptions[#radialExpressionsOptions + 1] = {
            label = expression.Label,
            icon = 'face-angry',
            onSelect = function()
                SetExpression(expression.Expression)
            end
        }
    end

    pr_lib.registerRadial({
        id = 'emotemenu_expressions',
        items = radialExpressionsOptions
    })

    pr_lib.registerRadial({
        id = 'emotemenu_main',
        items = {
            {
                id = 'emotemenu_open',
                label = locale('open_radial_menu'),
                icon = 'person-walking',
                onSelect = ToggleMenu
            },
            {
                id = 'emotemenu_walks_submenu',
                label = locale('walking_styles'),
                icon = 'person-walking',
                menu = 'emotemenu_walks'
            },
            {
                id = 'emotemenu_expressions_submenu',
                label = locale('facial_expressions'),
                icon = 'face-angry',
                menu = 'emotemenu_expressions'
            },
            {
                id = 'emotemenu_cancel',
                label = locale('cancel'),
                icon = 'ban',
                onSelect = CancelEmote
            }
        }
    })

    pr_lib.addRadialItem({{
        id = 'emotemenu_open',
        label = locale('emote_menu'),
        icon = 'person-walking',
        menu = 'emotemenu_main'
    }})
end

---Add a new menu option to the emote menu
function AddEmoteMenuOption(data)
    Emotes[#Emotes + 1] = data

    RegisterMenu()
end
exports('addEmoteMenuOption', AddEmoteMenuOption)

for i = 1, #Config.menuCommands do
    Utils.addCommand(Config.menuCommands[i], {
        help = locale('open_emote_menu')
    }, function(source, args, raw)
        ToggleMenu()
    end)
end

if Config.menuKeybind ~= '' then
    if #Config.menuCommands > 0 then
        RegisterKeyMapping(Config.menuCommands[1], locale('open_emote_menu'), 'keyboard', Config.menuKeybind)
    end
end

CreateThread(function()
    Wait(1000)

    RegisterMenu()

    if Config.enableRadialMenu then
        RegisterRadialMenu()
    end
end)
