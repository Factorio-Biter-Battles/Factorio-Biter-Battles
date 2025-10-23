local bb_tables = require('maps.biter_battles_v2.tables')
local bb_functions = require('maps.biter_battles_v2.functions')
local feeding_calculations = require('maps.biter_battles_v2.feeding_calculations')
local utils = require('utils.utils')

---Returns true if `str` starts with `prefix`
---@param str string
---@param prefix string
---@return boolean
local function starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---Removes `prefix` from `str` and returns the remaining part. Returns nil if prefix doesn't match
---@param str string
---@param prefix string
---@return string? suffix
local function strip_prefix(str, prefix)
    return starts_with(str, prefix) and str:sub(#prefix + 1) or nil
end

---Compares `force` with 'nth'/'sth' or matches as prefix of 'north'/'south'
---(this implies collision of 's' with 'space' science name)
---@param force string
---@return 'north'|'south'?
local function parse_force(force)
    if force == 'nth' then
        return 'north'
    end

    if force == 'sth' then
        return 'south'
    end

    if #force > 0 then
        for _, side in pairs({ 'north', 'south' }) do
            if starts_with(side, force) then
                return side
            end
        end
    end

    return nil
end

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

-- entries ordered by resolution priority, so for example 'b' will match 'blue' and not 'black'. First subentry is the canonical name
local sci_alias_priority = {
    { 'automation-science-pack', 'red' },
    { 'logistic-science-pack', 'green' },
    { 'chemical-science-pack', 'blue' },
    { 'military-science-pack', 'gray', 'grey', 'black' }, -- lower priority than green, blue
    { 'production-science-pack', 'purple' },
    { 'utility-science-pack', 'yellow' },
    { 'space-science-pack', 'white' },
}

-- Matches `name` as prefix of science name or alias, returns canonical name
---@param name string
---@return string? canonical_sci_name
local function parse_science_pack(name)
    for _, sci in pairs(sci_alias_priority) do
        for _, alias in pairs(sci) do
            if starts_with(alias, name) then
                return sci[1]
            end
        end
    end
    return nil
end

-- Parses numbers like 123, 1.2k and returns an integer
---@param num string
---@return number?
local function parse_count(num)
    local whole, fraction, suffix = num:match('^(%d*)%.?(%d*)(k?)$')
    if not whole or (whole == '' and fraction == '') then
        return nil
    end
    local result = whole ~= '' and tonumber(whole) or 0
    if suffix ~= '' then
        fraction = fraction ~= '' and tonumber(fraction:sub(1, 3)) * 10 ^ (3 - math.min(#fraction, 3)) or 0
        result = result * 1000 + fraction
    end
    return result
end

local prototypes_with_sci_inventory = {
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

local prototype_to_sci_inventory = {
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
local sci_display_priority = {}
for sci_name, _ in pairs(bb_tables.food_values) do
    sci_display_priority[#sci_display_priority + 1] = sci_name
end
table.sort(sci_display_priority, function(a, b)
    return bb_tables.food_values[a].value >= bb_tables.food_values[b].value
end)

---@param evo number
---@return string
local function biter_icon_for(evo)
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

-- helper function to avoid trailing zeros in formatting, e.g. 1 formatted as '%.1f' will be printed as 1.0, which is undesirable

---@param n number
---@return number
local function trim_to_1_decimal_place(n)
    return (n < 0 and -1 or 1) * math.floor(math.abs(n) * 10) / 10
end

---Formats big numbers as more readable with SI suffix (aka "1.5k")
---@param n number
---@return string
local function format_in_short_number_notation(n)
    local m = math.abs(n)
    if m < 1e3 then
        return tostring(trim_to_1_decimal_place(n))
    elseif m < 1e6 then
        return trim_to_1_decimal_place(n / 1e3) .. 'k'
    elseif m < 1e9 then
        return trim_to_1_decimal_place(n / 1e6) .. 'M'
    elseif m < 1e12 then
        return trim_to_1_decimal_place(n / 1e9) .. 'G'
    else
        return trim_to_1_decimal_place(n / 1e12) .. 'T'
    end
end

---Returns color string for '[color=%s]' tag corresponding to the `evo` level
---@param evo number
---@return string
local function evo_color(evo)
    if evo <= 1 / 6 then
        return '0.78,0.61,0.37'
    elseif evo <= 0.5 then
        return '0.67,0.40,0.43'
    elseif evo <= 0.9 then
        return '0.36,0.45,0.62'
    else
        return '0.5,0.58,0.11'
    end
end

local threat_colors = {
    negative = {
        '0.6,1,0.6',
        '0.4,1,0.4',
        '0.3,1,0.3',
        '0,1,0',
        '0,0.74,0',
        '0,0.65,0',
        '0,0.5,0',
    },
    positive = {
        '1,0.6,0.6',
        '1,0.4,0.4',
        '1,0.3,0.3',
        '1,0,0',
        '0.74,0,0',
        '0.65,0,0',
        '0.5,0,0',
    },
}

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

    -- return colors[math.floor(math.log(threat, 10)) + 1]
    local t = math.log(threat, 1000000)
    local c = {}
    for i = 1, 3 do
        c[i] = lerp(a[i], b[i], t)
    end
    return string.format('%.2f,%.2f,%.2f', c[1], c[2], c[3])
end

local usage_info = 'Usage: "/q north purple 1000" or shorter form "/q p1k"\n'
    .. 'Usage: "/q" calculate send from surrounding containers and self\n'
    .. 'Usage: "/q" (remote view) calculate send from characters/containers on the screen'

-- side of the bounding square
local sci_search_distance_span = 2 * 32

---@param player LuaPlayer?
---@param params string?
---@return string
local function quick_calc_send(player, params)
    local function format_error(...)
        local result = { 'Error: ' }
        for i = 1, select('#', ...) do
            result[#result + 1] = select(i, ...)
        end
        result[#result + 1] = '\n'
        result[#result + 1] = usage_info
        return table.concat(result)
    end

    local foods = {}

    params = params or ''
    local pending_sci = nil
    local pending_count = nil

    -- special value 'all' for both forces, can't be overwritten
    local maybe_force = nil

    local function accept_force(force)
        force = parse_force(force)
        if not force then
            return false
        end
        if not maybe_force then
            maybe_force = force
        end
        return true
    end

    local function accept_science_pack(name)
        name = parse_science_pack(name)
        if not name then
            return false
        end
        if pending_count then
            foods[name] = (foods[name] or 0) + pending_count
            pending_count = nil
        else
            pending_sci = name
        end
        return true
    end

    local function accept_count(count)
        count = parse_count(count)
        if not count or count > 1000000000 then
            return false
        end
        if pending_sci then
            foods[pending_sci] = (foods[pending_sci] or 0) + count
            pending_sci = nil
        else
            pending_count = count
        end
        return true
    end

    local empty_params = true
    for orig_param in string.gmatch(params, '%g+') do
        empty_params = false

        local param = orig_param:lower()

        if param == 'usage' then
            return usage_info
        end

        -- for backward compatibility with muscle memory of /calc-send
        local force = strip_prefix(param, 'force=')
        if force then
            if not accept_force(force) then
                -- ignore the error and print for both forces instead
                maybe_force = 'all'
            end
            goto continue
        end
        local color = strip_prefix(param, 'color=') or strip_prefix(param, 'colour=')
        if color then
            if not accept_science_pack(color) then
                return format_error('unknown color in "', orig_param, '"')
            end
            goto continue
        end
        local count = strip_prefix(param, 'count=')
        if count then
            if not accept_count(count) then
                return format_error('invalid count value in "', orig_param, '"')
            end
            goto continue
        end

        -- accept input as standalone tokens
        local accepted = accept_force(param) or accept_science_pack(param)
        if accepted then
            goto continue
        end

        -- accept count prefixed/suffixed with sci alias
        local sci, count = param:match('^(%a+)(%A+k?)$')
        if not sci then
            count, sci = param:match('^(%A+k?)(%a*)$')
        end
        if sci and sci ~= '' then
            pending_sci = nil
            pending_count = nil
        end
        if not count or count == '' or not accept_count(count) or (sci ~= '' and not accept_science_pack(sci)) then
            return format_error('invalid token "', orig_param, '"')
        end

        ::continue::
    end

    local calc_forces

    local function receiving_force(from)
        return storage.training_mode and from or (from == 'north' and 'south' or 'north')
    end

    -- calculate send from view point
    if empty_params then
        if not player then
            -- nothing to view from the console
            return usage_info
        end

        local force = player.force.name
        if force ~= 'north' and force ~= 'south' then
            force = player.position.y >= 0 and 'south' or 'north'
        end
        local pos = player.position
        local search_bbox = {
            left_top = { x = pos.x - sci_search_distance_span / 2, y = pos.y - sci_search_distance_span / 2 },
            right_bottom = { x = pos.x + sci_search_distance_span / 2, y = pos.y + sci_search_distance_span / 2 },
        }
        local visible_areas = player.controller_type == defines.controllers.remote
                and visible_area(search_bbox, player.force, player.surface)
            or { search_bbox }
        local processed_entities = {}
        for _, area in pairs(visible_areas) do
            local entities = player.surface.find_entities_filtered({
                area = area,
                force = { force, 'neutral' }, -- corpses are neutral
                type = prototypes_with_sci_inventory,
            })
            for _, e in pairs(entities) do
                if not processed_entities[e] then
                    local inventory = e.get_inventory(prototype_to_sci_inventory[e.type])
                    if inventory then
                        for sci, _ in pairs(bb_tables.food_names) do
                            local count = inventory.get_item_count(sci)
                            if count > 0 then
                                foods[sci] = (foods[sci] or 0) + count
                            end
                        end
                    end
                    processed_entities[e] = true
                end
            end
        end

        calc_forces = { receiving_force(force) }
    else
        if not maybe_force then
            if player and (player.force.name == 'north' or player.force.name == 'south') then
                calc_forces = { receiving_force(player.force.name) }
            else
                calc_forces = { 'north', 'south' }
            end
        elseif maybe_force == 'all' then
            calc_forces = { 'north', 'south' }
        else
            calc_forces = { maybe_force }
        end
    end

    local total_food = 0
    for sci, count in pairs(foods) do
        total_food = total_food + count * bb_tables.food_values[sci].value
    end
    if total_food == 0 then
        if empty_params then
            return 'No science packs were found around'
        else
            return format_error('no science name/color or count was specified')
        end
    end

    local result = {}
    local function append(...)
        for i = 1, select('#', ...) do
            result[#result + 1] = select(i, ...)
        end
    end

    append('Science')
    for _, sci in ipairs(sci_display_priority) do
        if foods[sci] and foods[sci] > 0 then
            append(' [img=item/', sci, '][font=heading-1][color=255,255,255]', foods[sci], '[/color][/font]')
        end
    end

    local player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    for _, force in pairs(calc_forces) do
        append('\nIf fed to ', bb_functions.team_name_with_color(force), ':\n')

        local biter_force = force .. '_biters'
        local evo = storage.bb_evolution[biter_force]
        local effects = feeding_calculations.calc_feed_effects(
            evo,
            total_food * storage.difficulty_vote_value,
            1,
            player_count,
            storage.max_reanim_thresh
        )

        local new_evo = evo + effects.evo_increase
        append(
            '• Evo ',
            biter_icon_for(evo),
            '[color=',
            evo_color(evo),
            ']',
            trim_to_1_decimal_place(evo * 100),
            '[/color]',
            ' → ',
            biter_icon_for(new_evo),
            '[color=',
            evo_color(new_evo),
            ']',
            trim_to_1_decimal_place(new_evo * 100),
            '[/color]\n'
        )

        local threat = storage.bb_threat[biter_force]
        threat = (threat < 0 and -1 or 1) * math.floor(math.abs(threat)) -- round towards 0
        local threat_increase = math.floor(effects.threat_increase)
        local new_threat = threat + threat_increase
        append(
            '• Threat [color=',
            threat_color(threat),
            ']',
            format_in_short_number_notation(threat),
            '[/color] → [color=',
            threat_color(new_threat),
            ']',
            format_in_short_number_notation(new_threat),
            '[/color] (+',
            format_in_short_number_notation(threat_increase),
            ')'
        )
    end
    return table.concat(result)
end

---@param cmd CustomCommandData
local function quick_calc_send_safe(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    local result = utils.safe_wrap_with_player_print(player, quick_calc_send, player, cmd.parameter)
    local print = player and player.print or game.print
    print(result)
end

commands.add_command(
    'q',
    'Calculate the impact of sending science (friendly version). Run "/q usage" for examples',
    quick_calc_send_safe
)

local Public = {}

---Calculate science send for the `player` using nearby science from his view
---@param player LuaPlayer
function Public.calc_send(player)
    local result = utils.safe_wrap_with_player_print(player, quick_calc_send, player, nil)
    game.print(result)
end

return Public
