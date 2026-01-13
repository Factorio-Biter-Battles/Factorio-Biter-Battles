local BbTables = require('maps.biter_battles_v2.tables')
local ClosableFrame = require('utils.ui.closable_frame')
local Color = require('utils.color_presets')
local FeedingCalculations = require('maps.biter_battles_v2.feeding_calculations')
local Event = require('utils.event')

local Public = {}

local THROTTLE_TICKS = 60 / 3
storage.calc_send_ui_throttle_timeout = {}

---Returns `true` if this expensive ui action should fail; updates the timeout
---@param player string
---@return boolean
local function throttle(player)
    local timeout = storage.calc_send_ui_throttle_timeout[player]
    if timeout and game.tick < timeout then
        return true
    end
    storage.calc_send_ui_throttle_timeout[player] = game.tick + THROTTLE_TICKS
    return false
end

---@param n number
---@return number
local function round_towards_zero(n)
    return (n < 0 and -1 or 1) * math.floor(math.abs(n))
end

---@param evo number
---@return string
local function icon_for_evo(evo)
    -- evo values are from biter_raffle
    if evo <= 1 / 6 then
        return '[img=entity/small-biter]'
    elseif evo <= 0.5 then
        return '[img=entity/medium-biter]'
    elseif evo <= 0.9 then
        return '[img=entity/big-biter]'
    else
        return '[img=entity/behemoth-biter]'
    end
end

---Returns color string for '[color=%s]' tag corresponding to the `evo` level
---@param evo number
---@return string
local function color_for_evo(evo)
    if evo <= 1 / 6 then
        return '0.89,0.71,0.44'
    elseif evo <= 0.5 then
        return '0.93,0.63,0.66'
    elseif evo <= 0.9 then
        return '0.46,0.59,0.71'
    else
        return '0.74,0.83,0.13'
    end
end

---Linearly interpolate between `a` and `b`. `t` domain is [0, 1]
---@param a number
---@param b number
---@param t number
---@return number
local function lerp(a, b, t)
    return a * (1 - t) + b * t
end

local threat_colors = {
    negative = { 0.2, 1, 0.2 },
    zero = { 1, 1, 1 },
    positive = { 1, 0.2, 0.2 },
}

---Returns color string for '[color=%s]' tag corresponding to the `threat` level
---@param threat number
---@return string
local function threat_color(threat)
    local a = threat_colors.zero
    if threat == 0 then
        return string.format('%.2f,%.2f,%.2f', a[1], a[2], a[3])
    end

    local b = threat < 0 and threat_colors.negative or threat_colors.positive
    threat = math.min(math.max(math.abs(threat), 1), 1000000)

    local t = math.log(threat, 1000000)
    local c = {}
    for i = 1, 3 do
        c[i] = lerp(a[i], b[i], t)
    end
    return string.format('%.2f,%.2f,%.2f', c[1], c[2], c[3])
end

---@param sending_force 'north'|'south'
---@return 'north'|'south'
local function receiving_force(sending_force)
    return storage.training_mode and sending_force or BbTables.enemy_team_of[sending_force]
end

--- Guesses food receiving force judging by designated team and game settings. Defaults to 'north'
---@param player LuaPlayer
---@return 'north'|'south' force
local function guess_receiving_force(player)
    local pf = player.force.name
    if pf == 'spectator' then
        pf = storage.chosen_team[player.name]
    end
    -- spectator or maybe in the editor with a weird force set
    if pf ~= 'north' and pf ~= 'south' then
        return 'north'
    end
    return receiving_force(pf)
end

---@class FeedEffects
---@field evo number fraction value, e.g. 1.0 = 100% evo
---@field evo_increase number fraction value
---@field threat number
---@field threat_increase number

---@param force 'north'|'south'
---@param food_value number
---@return FeedEffects
local function current_feed_effects(force, food_value)
    local player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    local biter_force = force .. '_biters'
    local evo, threat = storage.bb_evolution[biter_force], storage.bb_threat[biter_force]
    local effects = FeedingCalculations.calc_feed_effects(
        evo,
        food_value * storage.difficulty_vote_value,
        1,
        player_count,
        storage.max_reanim_thresh
    )
    return {
        evo = evo,
        evo_increase = effects.evo_increase,
        threat = threat,
        threat_increase = effects.threat_increase,
    }
end

---@param output_table LuaGuiElement
---@param recv_force 'north'|'south'
---@param foods { [string]: number }
local function update_output_table(output_table, recv_force, foods)
    output_table.clear()

    local total_food = 0
    for food, count in pairs(foods) do
        total_food = total_food + count * BbTables.food_values[food].value
    end

    local feed_effects = total_food == 0 and { evo = 0, evo_increase = 0, threat = 0, threat_increase = 0 }
        or current_feed_effects(recv_force, total_food)

    local evo, evo_increase, threat, threat_increase =
        feed_effects.evo, feed_effects.evo_increase, feed_effects.threat, feed_effects.threat_increase

    -- pick correct icons/colors before any normalizations
    local new_evo = evo + evo_increase
    local evo_icon, evo_color = icon_for_evo(evo), color_for_evo(evo)
    local new_evo_icon, new_evo_color = icon_for_evo(new_evo), color_for_evo(new_evo)

    -- normalize fractions to human readable values
    evo = evo * 100
    new_evo = new_evo * 100
    evo_increase = new_evo - evo

    threat = round_towards_zero(threat)
    threat_increase = math.floor(threat_increase)
    local new_threat = threat + threat_increase

    local output_rows = {
        {
            'Evo:',
            string.format('%s [color=%s]%.1f%%[/color]', evo_icon, evo_color, evo),
            string.format('%s [color=%s]%.1f%%[/color]', new_evo_icon, new_evo_color, new_evo),
            string.format('(+%.1f)', evo_increase),
        },
        {
            'Threat:',
            string.format(
                '[img=utility/enemy_force_icon] [color=%s]%s[/color]',
                threat_color(threat),
                threat_to_pretty_string(threat)
            ),
            string.format(
                '[img=utility/enemy_force_icon] [color=%s]%s[/color]',
                threat_color(new_threat),
                threat_to_pretty_string(new_threat)
            ),
            string.format('(+%s)', threat_to_pretty_string(threat_increase)),
        },
    }
    for _, row in ipairs(output_rows) do
        output_table.add({ type = 'label', style = 'caption_label', caption = row[1] })
        output_table.add({ type = 'label', style = 'semibold_label', caption = row[2] })
        output_table.add({ type = 'label', style = 'semibold_label', caption = '→' })
        output_table.add({ type = 'label', style = 'semibold_label', caption = row[3] })
        local value_increase = output_table.add({ type = 'label', style = 'semibold_label', caption = row[4] })
        value_increase.style.font_color = { 0.7, 0.7, 0.7 }
    end
end

---@param team_selector LuaGuiElement
---@return 'north'|'south'
local function get_selected_team(team_selector)
    return team_selector.switch_state == 'left' and 'north' or 'south'
end

---@param team_selector LuaGuiElement
---@param selected_team 'north'|'south'
local function update_team_selector(team_selector, selected_team)
    team_selector.switch_state = selected_team == 'north' and 'left' or 'right'
end

---@param food_table LuaGuiElement
---@param foods { [string]: number }
local function update_food_table(food_table, foods)
    for _, food in ipairs(BbTables.food_long_and_short) do
        local food_input = food_table[food.short_name .. '_count']
        local food_count = foods[food.long_name] or 0
        food_input.text = food_count == 0 and '' or tostring(food_count)
    end
end

---@return { [string]: boolean? }
local function get_disabled_food()
    return storage.active_special_games.disable_sciences and storage.special_games_variables.disabled_food or {}
end

--- Shows or hides food (science) sending calculator
---@param player LuaPlayer
function Public.toggle_calc_send_ui(player)
    local main_frame = player.gui.screen.calc_send
    if main_frame then
        main_frame.destroy()
        return
    end
    main_frame =
        ClosableFrame.create_main_closable_frame(player, 'calc_send', 'Calculate sending', { no_dragger = true })
    local content_layout = main_frame.add({
        type = 'flow',
        name = 'content_layout',
        style = 'inset_frame_container_vertical_flow',
        direction = 'vertical',
    })

    local output_frame = content_layout.add({
        type = 'frame',
        name = 'output_frame',
        style = 'inside_shallow_frame_with_padding',
        direction = 'vertical',
    })
    output_frame.style.minimal_width = 300
    output_frame.style.minimal_height = 70
    output_frame.style.horizontally_stretchable = true
    output_frame.style.vertical_align = 'center'
    output_frame.style.horizontal_align = 'left'

    local output_table = output_frame.add({ type = 'table', name = 'output_table', column_count = 5 })
    output_table.style.horizontal_spacing = 6

    local input_frame = content_layout.add({
        type = 'frame',
        name = 'input_frame',
        style = 'inside_shallow_frame_with_padding',
        direction = 'vertical',
    })
    local input_frame_layout =
        input_frame.add({ type = 'flow', name = 'input_frame_layout', style = 'vertical_flow', direction = 'vertical' })
    input_frame_layout.style.horizontal_align = 'center'
    input_frame_layout.style.horizontally_stretchable = true

    -- TODO move color coding to functions.lua?
    local team_selector = input_frame_layout.add({
        type = 'switch',
        name = 'team_selector',
        left_label_caption = '[color=120,120,255]North[/color]',
        right_label_caption = '[color=255,65,65]South[/color]',
        tooltip = 'Receiving side',
    })

    input_frame_layout.add({ type = 'line', style = 'inside_shallow_frame_with_padding_line' })

    local food_input_table = input_frame_layout.add({ type = 'table', name = 'food_input_table', column_count = 3 })
    local disabled_food = get_disabled_food()
    for _, food in ipairs(BbTables.food_long_and_short) do
        food_input_table.add({
            type = 'label',
            caption = string.format('[item=%s] %s', food.long_name, food.short_name),
        })
        local pusher = food_input_table.add({ type = 'empty-widget' })
        pusher.style.horizontally_stretchable = true
        local is_enabled = not disabled_food[food.long_name]
        local food_count = food_input_table.add({
            name = food.short_name .. '_count',
            type = 'textfield',
            numeric = true,
            tooltip = is_enabled and 'Right-click to clear' or 'Disabled by a special game',
        })
        food_count.style.width = 100
        food_count.enabled = is_enabled
    end

    local footer_with_buttons =
        content_layout.add({ type = 'flow', style = 'horizontal_flow', direction = 'horizontal' })
    footer_with_buttons.drag_target = main_frame
    footer_with_buttons.add({
        type = 'sprite-button',
        name = 'calc_send_fill_from_inventory',
        sprite = 'entity/character',
        style = 'tool_button',
        tooltip = 'Fill from the inventory',
    })
    footer_with_buttons.add({
        type = 'sprite-button',
        name = 'calc_send_fill_from_remote_view',
        sprite = 'item/radar',
        style = 'tool_button',
        tooltip = 'Fill from the remote view',
    })
    footer_with_buttons.add({
        type = 'sprite-button',
        name = 'calc_send_clear',
        sprite = 'utility/trash',
        style = 'tool_button_red',
        tooltip = 'Clear all',
    })
    local pusher = footer_with_buttons.add({ type = 'empty-widget' })
    pusher.ignored_by_interaction = true
    pusher.style.horizontally_stretchable = true
    local confirm_button = footer_with_buttons.add({
        name = 'calc_send_confirm',
        type = 'button',
        caption = 'Calculate',
        style = 'tool_button',
    })
    confirm_button.style.width = 120

    local recv_force = guess_receiving_force(player)
    update_team_selector(team_selector, recv_force)
    update_output_table(output_table, recv_force, {})
end

---@class CalcSendElements
---@field output_table LuaGuiElement evo/threat goes here
---@field team_selector LuaGuiElement north/south switch
---@field food_table LuaGuiElement table with food count input fields

---@param calc_send_frame LuaGuiElement
---@return CalcSendElements
local function find_calc_send_elements(calc_send_frame)
    local input_frame_layout = calc_send_frame.content_layout.input_frame.input_frame_layout
    return {
        output_table = calc_send_frame.content_layout.output_frame.output_table,
        team_selector = input_frame_layout.team_selector,
        food_table = input_frame_layout.food_input_table,
    }
end

---@param food_table LuaGuiElement
---@return { [string]: number } foods
local function collect_food_input(food_table)
    local foods = {}
    for _, food in ipairs(BbTables.food_long_and_short) do
        local food_input = food_table[food.short_name .. '_count']
        local food_count = tonumber(food_input.text)
        if food_count then
            foods[food.long_name] = food_count
        end
    end
    return foods
end

---@param foods { [string]: number } in/out
local function normalize_food_values(foods)
    for food, count in pairs(foods) do
        count = math.max(math.min(count, 1e9), 0)
        foods[food] = count == 0 and nil or count
    end
end

---@param inventory LuaInventory
---@param foods {[string]: number} accumulates values to this table
local function add_food_from_inventory(inventory, foods)
    local disabled_food = get_disabled_food()
    for _, food in ipairs(BbTables.food_long_and_short) do
        if not disabled_food[food.long_name] then
            local food_count = inventory.get_item_count(food.long_name)
            if food_count > 0 then
                foods[food.long_name] = (foods[food.long_name] or 0) + food_count
            end
        end
    end
end

---@param button LuaGuiElement
local function on_confirm_clicked(button)
    local calc_send_elems = find_calc_send_elements(button.gui.screen.calc_send)
    local foods = collect_food_input(calc_send_elems.food_table)
    normalize_food_values(foods)
    update_food_table(calc_send_elems.food_table, foods)
    update_output_table(calc_send_elems.output_table, get_selected_team(calc_send_elems.team_selector), foods)
end

---@param button LuaGuiElement
local function on_clear_clicked(button)
    local calc_send_elems = find_calc_send_elements(button.gui.screen.calc_send)
    update_food_table(calc_send_elems.food_table, {})
    update_output_table(calc_send_elems.output_table, get_selected_team(calc_send_elems.team_selector), {})
end

---@param button LuaGuiElement
local function on_fill_from_inventory_clicked(button)
    local calc_send_elems = find_calc_send_elements(button.gui.screen.calc_send)
    local player = button.gui.player

    local foods = {}
    local inventory = player.character and player.character.get_main_inventory()
    if inventory then
        add_food_from_inventory(inventory, foods)
    end

    local recv_force = guess_receiving_force(player)
    update_team_selector(calc_send_elems.team_selector, recv_force)
    update_food_table(calc_send_elems.food_table, foods)
    update_output_table(calc_send_elems.output_table, recv_force, foods)
end

local prototypes_with_food_inventory = {
    'car',
    'cargo-landing-pad',
    'cargo-pod',
    'cargo-wagon',
    'character',
    'character-corpse',
    'container',
    'logistic-container',
    'spider-vehicle',
    'temporary-container', -- landed cargo pod
}

local prototype_to_food_inventory = {
    ['car'] = defines.inventory.car_trunk,
    ['cargo-landing-pad'] = defines.inventory.cargo_landing_pad_main,
    ['cargo-pod'] = defines.inventory.cargo_unit,
    ['cargo-wagon'] = defines.inventory.cargo_wagon,
    ['character'] = defines.inventory.character_main,
    ['character-corpse'] = defines.inventory.character_corpse,
    ['container'] = defines.inventory.chest,
    ['logistic-container'] = defines.inventory.chest,
    ['spider-vehicle'] = defines.inventory.spider_trunk,
    ['temporary-container'] = defines.inventory.chest,
}

---Converts tile area into chunk area
---@param tile_area BoundingBox
---@return {left_top:  ChunkPosition, right_bottom:  ChunkPosition}
local function bounding_chunks(tile_area)
    return {
        left_top = {
            x = math.floor(tile_area.left_top.x / 32),
            y = math.floor(tile_area.left_top.y / 32),
        },
        right_bottom = {
            x = math.ceil(tile_area.right_bottom.x / 32),
            y = math.ceil(tile_area.right_bottom.y / 32),
        },
    }
end

-- in our case there are no negative intersections

---@param a BoundingBox
---@param b BoundingBox
---@return BoundingBox
local function intersection(a, b)
    return {
        left_top = {
            x = math.max(a.left_top.x, b.left_top.x),
            y = math.max(a.left_top.y, b.left_top.y),
        },
        right_bottom = {
            x = math.min(a.right_bottom.x, b.right_bottom.x),
            y = math.min(a.right_bottom.y, b.right_bottom.y),
        },
    }
end

--- Calculates surface area currently visible in the player's game viewport
---@param player LuaPlayer
---@return BoundingBox
local function viewport_area(player)
    -- from developer's 1v1 fork
    local d = 2 * 32 * player.zoom
    local dx = player.display_resolution.width / d
    local dy = player.display_resolution.height / d
    local pos = player.position
    return { left_top = { x = pos.x - dx, y = pos.y - dy }, right_bottom = { x = pos.x + dx, y = pos.y + dy } }
end

--- Subdivides area into visible subareas.
--- This is not optimal, but should be good enough for small areas
---@param area BoundingBox
---@param force LuaForce
---@param surface LuaSurface
---@return BoundingBox[]
local function visible_area(area, force, surface)
    local result = {}
    local chunk_area = bounding_chunks(area)
    for y = chunk_area.left_top.y, chunk_area.right_bottom.y - 1 do
        for x = chunk_area.left_top.x, chunk_area.right_bottom.x - 1 do
            if force.is_chunk_visible(surface, { x, y }) then
                local chunk = {
                    left_top = { x = x * 32, y = y * 32 },
                    right_bottom = { x = (x + 1) * 32, y = (y + 1) * 32 },
                }
                result[#result + 1] = intersection(chunk, area)
            end
        end
    end
    return result
end

-- side of the square to limit search area
local FOOD_SEARCH_SPAN = 2 * 32

local ENTITY_LIMIT = 500

---@param button LuaGuiElement
local function on_fill_from_remote_view_clicked(button)
    local calc_send_elems = find_calc_send_elements(button.gui.screen.calc_send)
    local player = button.gui.player

    if throttle(player.name) then
        return
    end

    local foods = {}

    -- notice that we don't care about the type of controller
    local sending_force = player.force.name
    if sending_force ~= 'north' and sending_force ~= 'south' then
        sending_force = player.position.y >= 0 and 'south' or 'north'
    end

    local pos = player.position
    local dl = FOOD_SEARCH_SPAN / 2
    local limit = { left_top = { x = pos.x - dl, y = pos.y - dl }, right_bottom = { x = pos.x + dl, y = pos.y + dl } }
    local search_bbox = intersection(viewport_area(player), limit)

    local visible_areas = player.controller_type == defines.controllers.remote
            and visible_area(search_bbox, player.force --[[@as LuaForce]], player.surface)
        or { search_bbox }
    local processed_entities = {}
    local entity_limit = ENTITY_LIMIT
    for _, area in pairs(visible_areas) do
        local entities = player.surface.find_entities_filtered({
            area = area,
            force = { sending_force, 'neutral' }, -- corpses are neutral
            type = prototypes_with_food_inventory,
            limit = entity_limit,
        })
        for _, e in pairs(entities) do
            if not processed_entities[e] then
                local inventory = e.get_inventory(prototype_to_food_inventory[e.type])
                if inventory then
                    add_food_from_inventory(inventory, foods)
                end
                processed_entities[e] = true
            end
        end
        entity_limit = entity_limit - #entities
        if entity_limit == 0 then
            player.print(
                "'Fill from the remove view' hit the entity count limit, some values may be inaccurate",
                { color = Color.yellow }
            )
            break
        end
    end

    local recv_force = receiving_force(sending_force)
    update_team_selector(calc_send_elems.team_selector, recv_force)
    update_food_table(calc_send_elems.food_table, foods)
    update_output_table(calc_send_elems.output_table, recv_force, foods)
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
    local element = event.element
    if not element.valid then
        return
    end

    if element.name == 'calc_send_confirm' then
        on_confirm_clicked(element)
    elseif element.name == 'calc_send_clear' then
        on_clear_clicked(element)
    elseif element.name == 'calc_send_fill_from_inventory' then
        on_fill_from_inventory_clicked(element)
    elseif element.name == 'calc_send_fill_from_remote_view' then
        on_fill_from_remote_view_clicked(element)
    end
end
Event.add(defines.events.on_gui_click, on_gui_click)

return Public
