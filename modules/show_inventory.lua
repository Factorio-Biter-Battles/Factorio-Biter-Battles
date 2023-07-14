local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local Event = require 'utils.event'

local this = {
    data = {},
    tracking = {},
}
local Public = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

local space = {
    minimal_height = 10,
    top_padding = 0,
    bottom_padding = 0
}

local function get_player_data(player, remove)
    if remove and this.data[player.index] then
        this.data[player.index] = nil
        return
    end
    if not this.data[player.index] then
        this.data[player.index] = {}
    end
    return this.data[player.index]
end

local function addStyle(guiIn, styleIn)
    for k, v in pairs(styleIn) do
        guiIn.style[k] = v
    end
end

local function adjustSpace(guiIn)
    addStyle(guiIn.add {type = 'line', direction = 'horizontal'}, space)
end

local function validate_object(obj)
    if not obj then
        return false
    end
    if not obj.valid then
        return false
    end
    return true
end

local function player_opened(player)
    local data = get_player_data(player)

    if not data then
        return false
    end

    local opened = data.player_opened

    if not validate_object(opened) then
        return false
    end

    return true, opened
end

local function last_tab(player)
    local data = get_player_data(player)

    if not data then
        return false
    end

    local tab = data.last_tab
    if not tab then
        return false
    end

    return true, tab
end

local function validate_player(player)
    if not player then
        return false
    end
    if not player.valid then
        return false
    end
    if not player.character then
        return false
    end
    if not player.connected then
        return false
    end
    if not game.get_player(player.index) then
        return false
    end
    return true
end


local function stop_watching_all(player_index)
    for _, watchers in pairs(this.tracking) do
        watchers[player_index] = nil
    end
end

local function stop_watching(player_index, target_index)
    if not this.tracking[target_index] then
        return
    end
    this.tracking[target_index][player_index] = nil
end

local function close_player_inventory(player)
    local data = get_player_data(player)

    if not data then
        return
    end

    if not data.player_opened then
        return
    end

    stop_watching(player.index, data.player_opened.index)

    local gui = player.gui.screen

    if not validate_object(gui) then
        return
    end

    local element = gui.inventory_gui

    if not validate_object(element) then
        return
    end

    element.destroy()
    get_player_data(player, true)
end

local function redraw_inventory(gui, source, target, caption, panel_type)
    gui.clear()

    local items_table = gui.add({type = 'table', column_count = 11})
    local types = game.item_prototypes

    local screen = source.gui.screen

    if not validate_object(screen) then
        return
    end

    local inventory_gui = screen.inventory_gui

    inventory_gui.caption = 'Inventory of ' .. target.name

    for name, opts in pairs(panel_type) do
        local flow = items_table.add({type = 'flow'})
        flow.style.vertical_align = 'bottom'

        local button =
            flow.add(
            {
                type = 'sprite-button',
                sprite = 'item/' .. name,
                number = opts,
                name = name,
                tooltip = types[name].localised_name,
                style = 'slot_button'
            }
        )
        button.enabled = false

        if caption == 'Armor' then
            if target.get_inventory(5)[1].grid then
                local p_armor = target.get_inventory(5)[1].grid.get_contents()
                for k, v in pairs(p_armor) do
                    local armor_gui =
                        flow.add(
                        {
                            type = 'sprite-button',
                            sprite = 'item/' .. k,
                            number = v,
                            name = k,
                            tooltip = types[name].localised_name,
                            style = 'slot_button'
                        }
                    )
                    armor_gui.enabled = false
                end
            end
        end
    end
end

local function add_inventory(panel, source, target, caption, panel_type)
    local data = get_player_data(source)
    data.panel_type = data.panel_type or {}
    local pane_name = panel.add({type = 'tab', caption = caption, name = caption})
    local scroll_pane =
        panel.add {
        type = 'scroll-pane',
        name = caption .. 'tab',
        direction = 'vertical',
        vertical_scroll_policy = 'always',
        horizontal_scroll_policy = 'never'
    }
    scroll_pane.style.maximal_height = 200
    scroll_pane.style.horizontally_stretchable = true
    scroll_pane.style.minimal_height = 200
    scroll_pane.style.right_padding = 0
    panel.add_tab(pane_name, scroll_pane)

    data.panel_type[caption] = panel_type

    redraw_inventory(scroll_pane, source, target, caption, panel_type)
end

local function open_inventory(source, target)
    if not validate_player(source) then
        return
    end

    if not validate_player(target) then
        return
    end

    local screen = source.gui.screen

    if not validate_object(screen) then
        return
    end

    local inventory_gui = screen.inventory_gui
    if inventory_gui then
        close_player_inventory(source)
    end

    local frame =
        screen.add(
        {
            type = 'frame',
            caption = 'Inventory',
            direction = 'vertical',
            name = 'inventory_gui'
        }
    )

    if not validate_object(frame) then
        return
    end

    frame.auto_center = true
    source.opened = frame
    frame.style.minimal_width = 500
    frame.style.minimal_height = 250

    adjustSpace(frame)

    local panel = frame.add({type = 'tabbed-pane', name = 'tabbed_pane'})
    panel.selected_tab_index = 1

    local data = get_player_data(source)

    if not this.tracking[target.index] then this.tracking[target.index] = {} end
    this.tracking[target.index][source.index] = true

    data.player_opened = target
    data.last_tab = 'Main'

    local main = target.get_main_inventory().get_contents()
    local armor = target.get_inventory(defines.inventory.character_armor).get_contents()
    local guns = target.get_inventory(defines.inventory.character_guns).get_contents()
    local ammo = target.get_inventory(defines.inventory.character_ammo).get_contents()
    local trash = target.get_inventory(defines.inventory.character_trash).get_contents()

    local types = {
        ['Main'] = main,
        ['Armor'] = armor,
        ['Guns'] = guns,
        ['Ammo'] = ammo,
        ['Trash'] = trash
    }

    for k, v in pairs(types) do
        if v ~= nil then
            add_inventory(panel, source, target, k, v)
        end
    end
end

local function on_gui_click(event)

    local element = event.element

    if not element or not element.valid then
        return
    end

    local types = {
        ['Main'] = true,
        ['Armor'] = true,
        ['Guns'] = true,
        ['Ammo'] = true,
        ['Trash'] = true
    }

    local name = element.name

    if not types[name] then
        return
    end
    local player = game.get_player(event.player_index)

    local data = get_player_data(player)
    if not data then
        return
    end

    data.last_tab = name

    local valid, target = player_opened(player)

    if valid then
        local target_inventories = {
            ['Main'] = function()
                return target.get_main_inventory().get_contents()
            end,
            ['Armor'] = function()
                return target.get_inventory(defines.inventory.character_armor).get_contents()
            end,
            ['Guns'] = function()
                return target.get_inventory(defines.inventory.character_guns).get_contents()
            end,
            ['Ammo'] = function()
                return target.get_inventory(defines.inventory.character_ammo).get_contents()
            end,
            ['Trash'] = function()
                return target.get_inventory(defines.inventory.character_trash).get_contents()
            end
        }

        local frame = Public.get_active_frame(player)
        local panel_type = target_inventories[name]()

        redraw_inventory(frame, player, target, name, panel_type)
    end
end
local function gui_closed(event)

    local type = event.gui_type

    if type == defines.gui_type.custom then
        local player = game.get_player(event.player_index)
        local data = get_player_data(player)
        if not data then
            return
        end
        close_player_inventory(player)
    end
end

local function on_pre_player_left_game(event)
    local player = game.get_player(event.player_index)
    close_player_inventory(player)
end

local function close_watchers(player)
    local watchers = this.tracking[player.index]

    if watchers == nil then
        return
    end

    for watcher_idx, _ in pairs(watchers) do
        local watcher = game.get_player(watcher_idx)

        if not validate_object(watcher) then goto continue end

        close_player_inventory(watcher)

        ::continue::
    end
end

local function update_gui(event)
    local watchers = this.tracking[event.player_index]

    -- can we skip updating GUIs for this change (are there no players watching?)
    if watchers == nil then
        return
    end
    
    if table_size(watchers) <= 0 then
        this.tracking[event.player_index] = nil
        return
    end

    local target = game.get_player(event.player_index)
    if not validate_object(target) then
        close_watchers(target)
    end

    -- lazy evaluation of target inventories, avoid performance overhead
    -- of getting all inventories if only some are watched
    local target_inventories = {
        ['Main'] = function()
            return target.get_main_inventory().get_contents()
        end,
        ['Armor'] = function()
            return target.get_inventory(defines.inventory.character_armor).get_contents()
        end,
        ['Guns'] = function()
            return target.get_inventory(defines.inventory.character_guns).get_contents()
        end,
        ['Ammo'] = function()
            return target.get_inventory(defines.inventory.character_ammo).get_contents()
        end,
        ['Trash'] = function()
            return target.get_inventory(defines.inventory.character_trash).get_contents()
        end
    }

    local cache = {}

    local function cache_get(key)
        if not cache[key] then
            cache[key] = target_inventories[key]()
        end
        return cache[key]
    end

    for watcher_idx, _ in pairs(watchers) do
        local watcher = game.get_player(watcher_idx)

        if not validate_object(watcher) then
            stop_watching_all(watcher_idx)
            goto continue
        end
        if not watcher.connected then
            stop_watching_all(watcher_idx)
            goto continue
        end

        local success, tab = last_tab(watcher)
        if success then

            local frame = Public.get_active_frame(watcher)
            local panel_type = cache_get(tab)
            if frame and frame.name == tab .. 'tab' then
                redraw_inventory(frame, watcher, target, tab, panel_type)
            end
        end
        ::continue::
    end
end

commands.add_command(
    'inventory',
    'Opens a players inventory!',
    function(cmd)
        local player = game.player

        if validate_player(player) then
            if not cmd.parameter then
                return
            end
            local target_player = game.get_player(cmd.parameter)

            local valid, opened = player_opened(player)
            if valid then
                if target_player == opened then
                    return player.print('You are already viewing this players inventory.', Color.warning)
                end
            end

            if validate_player(target_player) then
                open_inventory(player, target_player)
            else
                player.print('Please type a name of a player who is connected.', Color.warning)
            end
        else
            return
        end
    end
)

function Public.get_active_frame(player)
    if not player.gui.screen.inventory_gui then
        return false
    end
    return player.gui.screen.inventory_gui.tabbed_pane.tabs[
        player.gui.screen.inventory_gui.tabbed_pane.selected_tab_index
    ].content
end

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

Event.add(defines.events.on_player_main_inventory_changed, update_gui)
Event.add(defines.events.on_player_gun_inventory_changed, update_gui)
Event.add(defines.events.on_player_ammo_inventory_changed, update_gui)
Event.add(defines.events.on_player_armor_inventory_changed, update_gui)
Event.add(defines.events.on_player_trash_inventory_changed, update_gui)
Event.add(defines.events.on_gui_closed, gui_closed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_pre_player_left_game, on_pre_player_left_game)

return Public
