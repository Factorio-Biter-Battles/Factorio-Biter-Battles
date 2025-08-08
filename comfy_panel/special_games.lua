local Event = require('utils.event')
local Color = require('utils.color_presets')
local Public = {}
storage.active_special_games = {}
storage.special_games_variables = {}
storage.next_special_games = {}
storage.next_special_games_variables = {}

local valid_special_games = {
    turtle = require('comfy_panel.special_games.turtle'),
    multi_silo = require('comfy_panel.special_games.multi_silo'),
    infinity_chest = require('comfy_panel.special_games.infinity_chest'),
    disabled_research = require('comfy_panel.special_games.disabled_research'),
    disabled_entities = require('comfy_panel.special_games.disabled_entities'),
    shared_science_throw = require('comfy_panel.special_games.shared_science_throw'),
    limited_lives = require('comfy_panel.special_games.limited_lives'),
    mixed_ore_map = require('comfy_panel.special_games.mixed_ore_map'),
    disable_sciences = require('comfy_panel.special_games.disable_sciences'),
    send_to_external_server = require('comfy_panel.special_games.send_to_external_server'),
    captain = require('comfy_panel.special_games.captain'),
    threat_farm_threshold = require('comfy_panel.special_games.threat_farm_threshold'),
    --[[
    Add your special game here.
    Syntax:
    <game_name> = require 'comfy_panel.special_games.<game_name>',

    Create file special_games/<game_name>.lua
    See file special_games/example.lua for an example
    ]]
}

local function clear_gui_specials()
    local captain_event = require('comfy_panel.special_games.captain')
    captain_event.clear_gui_special()
end

function Public.reset_special_games()
    storage.active_special_games = storage.next_special_games
    storage.special_games_variables = storage.next_special_games_variables
    storage.next_special_games = {}
    storage.next_special_games_variables = {}
    clear_gui_specials()
    local captain_event = require('comfy_panel.special_games.captain')
    captain_event.reset_special_games()
end

local create_special_games_panel = function(player, frame)
    frame.clear()
    frame.add({ type = 'label', caption = 'Configure and apply special games here' }).style.single_line = false
    local sp = frame.add({ type = 'scroll-pane', horizontal_scroll_policy = 'never' })
    sp.style.vertically_squashable = true
    sp.style.padding = 2
    for k, v in pairs(valid_special_games) do
        local a = sp.add({ type = 'frame' })
        a.style.horizontally_stretchable = true
        local table = a.add({ name = k, type = 'table', column_count = 3, draw_vertical_lines = true })
        table.add(v.name).style.width = 110
        local config = table.add({ name = k .. '_config', type = 'flow', direction = 'horizontal' })
        config.style.horizontally_stretchable = true
        config.style.left_padding = 3
        for _, i in ipairs(v.config) do
            config.add(i)
            config[i.name].style.width = i.width
        end
        table.add({ name = v.button.name, type = v.button.type, caption = v.button.caption })
        table[k .. '_config'].style.vertical_align = 'center'
    end
end

local function is_element_child_of(element, parent_name)
    if element.parent then
        if element.parent.name == parent_name then
            return true
        end

        return is_element_child_of(element.parent, parent_name)
    end

    return false
end

local function get_sepecial_game_table(element)
    if element.parent then
        if element.parent.type == 'table' and valid_special_games[element.parent.name] then
            return element.parent
        end

        return get_sepecial_game_table(element.parent)
    end

    return nil
end

local function on_gui_click(event)
    local element = event.element
    if not element then
        return
    end
    if not element.valid then
        return
    end
    if not (element.type == 'button') then
        return
    end
    if not is_element_child_of(element, 'Special games') then
        return
    end

    local special_game_gui = get_sepecial_game_table(element)
    if not special_game_gui then
        return
    end

    local config = special_game_gui.children[2]
    local player = game.get_player(event.player_index)

    if element.name == 'confirm' or element.name == 'cancel' then
        if element.name == 'confirm' then
            valid_special_games[special_game_gui.name].generate(config, player)
        end

        if not element.valid then
            return
        end
        special_game_gui.children[3].visible = true -- shows back Apply button
        element.parent.destroy() -- removes confirm/Cancel buttons
    elseif element.name == 'apply' then
        local flow = element.parent.add({ type = 'flow', direction = 'vertical' })
        flow.add({ type = 'button', name = 'confirm', caption = 'Confirm' })
        flow.add({ type = 'button', name = 'cancel', caption = 'Cancel' })
        element.visible = false -- hides Apply button
        player.print(
            '[SPECIAL GAMES] Are you sure? This change will be reversed only on map restart!',
            { color = Color.cyan }
        )
    elseif valid_special_games[special_game_gui.name]['gui_click'] then
        valid_special_games[special_game_gui.name].gui_click(element, config, player)
    end
end

comfy_panel_tabs['Special games'] = { gui = create_special_games_panel, admin = true }

Event.add(defines.events.on_gui_click, on_gui_click)

return Public
