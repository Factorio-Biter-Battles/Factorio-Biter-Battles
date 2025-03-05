local bb_config = require('maps.biter_battles_v2.config')
local FeedingCalculations = require('maps.biter_battles_v2.feeding_calculations')
local Functions = require('maps.biter_battles_v2.functions')
local Server = require('utils.server')
local Quality = require('maps.biter_battles_v2.quality')
local ScienceLogs = require('maps.biter_battles_v2.sciencelogs_tab')
local Text = require('utils.rich_text')
local Player = require('utils.player')
local Table = require('utils.table')
local tables = require('maps.biter_battles_v2.tables')
local food_values = tables.food_values
local force_translation = tables.force_translation
local enemy_team_of = tables.enemy_team_of
local math_floor = math.floor
local math_round = math.round
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print

local Public = {}

local function update_boss_modifiers(force_name_biter, damage_mod_mult, speed_mod_mult)
    local damage_mod = math_round(storage.bb_evolution[force_name_biter] * 1.0, 3) * damage_mod_mult
    local speed_mod = math_round(storage.bb_evolution[force_name_biter] * 0.25, 3) * speed_mod_mult
    local force = game.forces[force_name_biter .. '_boss']
    force.set_ammo_damage_modifier('melee', damage_mod)
    force.set_ammo_damage_modifier('biological', damage_mod)
    force.set_ammo_damage_modifier('artillery-shell', damage_mod)
    force.set_ammo_damage_modifier('flamethrower', damage_mod)
    force.set_gun_speed_modifier('melee', speed_mod)
    force.set_gun_speed_modifier('biological', speed_mod)
    force.set_gun_speed_modifier('artillery-shell', speed_mod)
    force.set_gun_speed_modifier('flamethrower', speed_mod)
end

local function set_biter_endgame_modifiers(force)
    if force.get_evolution_factor(storage.bb_surface_name) ~= 1 then
        return
    end

    local damage_mod = math_round((storage.bb_evolution[force.name] - 1) * 1.0, 3)
    force.set_ammo_damage_modifier('melee', damage_mod)
    force.set_ammo_damage_modifier('biological', damage_mod)
    force.set_ammo_damage_modifier('artillery-shell', damage_mod)
    force.set_ammo_damage_modifier('flamethrower', damage_mod)
end

local function get_enemy_team_of(team)
    if storage.training_mode then
        return team
    else
        return enemy_team_of[team]
    end
end

--- @param player LuaPlayer?
--- @param feeding_force_name string
--- @param food string
--- @param flask_amount number
--- @param biter_force_name string
--- @param evo_before_science_feed number
--- @param threat_before_science_feed number
--- @param quality string
function Public.add_feeding_stats(
    player,
    feeding_force_name,
    food,
    flask_amount,
    biter_force_name,
    evo_before_science_feed,
    threat_before_science_feed,
    quality
)
    local nick = 'unknown player'
    if player then
        local color = Player.get_accent_color(player)
        nick = Text.colored(player.name, color)
    end

    local tier = Quality.TIER_DEFAULT
    local formatted_food = Text.img('item/' .. food)
    if Quality.enabled() then
        tier = Quality.tier_index_by_name(quality)
        formatted_food = formatted_food .. ' ' .. Text.quality(quality)
    end

    if tier == nil then
        log('wrong quality type')
        return
    end

    local formatted_amount =
        table.concat({ '[font=heading-1][color=255,255,255]' .. flask_amount .. '[/color][/font]' })
    if flask_amount > 0 then
        local tick = Functions.get_ticks_since_game_start()
        local feed_time_mins = math_round(tick / (60 * 60), 0)
        local minute_unit = ''
        if feed_time_mins <= 1 then
            minute_unit = 'min'
        else
            minute_unit = 'mins'
        end

        local shown_feed_time_hours = ''
        local shown_feed_time_mins = ''
        shown_feed_time_mins = feed_time_mins .. minute_unit
        local formatted_feed_time = shown_feed_time_hours .. shown_feed_time_mins
        evo_before_science_feed = math_round(evo_before_science_feed * 100, 1)
        threat_before_science_feed = math_round(threat_before_science_feed, 0)
        local formatted_evo_after_feed = math_round(storage.bb_evolution[biter_force_name] * 100, 1)
        local formatted_threat_after_feed = math_round(storage.bb_threat[biter_force_name], 0)
        local evo_jump = table.concat({ evo_before_science_feed .. ' to ' .. formatted_evo_after_feed })
        local threat_jump = table.concat({ threat_before_science_feed .. ' to ' .. formatted_threat_after_feed })
        local evo_jump_difference = math_round(formatted_evo_after_feed - evo_before_science_feed, 1)
        local threat_jump_difference = math_round(formatted_threat_after_feed - threat_before_science_feed, 0)
        local line_log_stats_to_add =
            table.concat({ formatted_amount .. ' ' .. formatted_food .. ' by ' .. nick .. ' to ' })
        local team_name_fed_by_science = get_enemy_team_of(feeding_force_name)

        if storage.science_logs_total_north == nil then
            storage.science_logs_total_north = ScienceLogs.init_science_total_table()
            storage.science_logs_total_south = ScienceLogs.init_science_total_table()
        end

        local total_science_of_player_force = nil
        if feeding_force_name == 'north' then
            total_science_of_player_force = storage.science_logs_total_north
        else
            total_science_of_player_force = storage.science_logs_total_south
        end

        local indexScience = tables.food_long_to_short[food].indexScience
        total_science_of_player_force[indexScience][tier] = total_science_of_player_force[indexScience][tier]
            + flask_amount

        if storage.science_logs_text then
            table.insert(storage.science_logs_date, 1, formatted_feed_time)
            table.insert(storage.science_logs_text, 1, line_log_stats_to_add)
            table.insert(storage.science_logs_evo_jump, 1, evo_jump)
            table.insert(storage.science_logs_evo_jump_difference, 1, evo_jump_difference)
            table.insert(storage.science_logs_threat, 1, threat_jump)
            table.insert(storage.science_logs_threat_jump_difference, 1, threat_jump_difference)
            table.insert(storage.science_logs_fed_team, 1, team_name_fed_by_science)
            table.insert(storage.science_logs_food_name, 1, food)
        else
            storage.science_logs_date = { formatted_feed_time }
            storage.science_logs_text = { line_log_stats_to_add }
            storage.science_logs_evo_jump = { evo_jump }
            storage.science_logs_evo_jump_difference = { evo_jump_difference }
            storage.science_logs_threat = { threat_jump }
            storage.science_logs_threat_jump_difference = { threat_jump_difference }
            storage.science_logs_fed_team = { team_name_fed_by_science }
            storage.science_logs_food_name = { food }
        end
    end
end

function Public.do_raw_feed(flask_amount, food, biter_force_name, tier)
    local force_index = game.forces[biter_force_name].index
    local decimals = 9

    local food_value = food_values[food].value * storage.difficulty_vote_value * Quality.TIERS[tier].multiplier

    local evo = storage.bb_evolution[biter_force_name]
    local threat = 0.0

    local current_player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    local effects = FeedingCalculations.calc_feed_effects(
        evo,
        food_value,
        flask_amount,
        current_player_count,
        storage.max_reanim_thresh
    )
    evo = evo + effects.evo_increase
    threat = threat + effects.threat_increase * (storage.threat_multiplier or 1)
    evo = math_round(evo, decimals)
    storage.biter_health_factor[force_index] = effects.biter_health_factor

    --SET THREAT INCOME
    storage.bb_threat_income[biter_force_name] = evo * 25

    game.forces[biter_force_name].set_evolution_factor(math.min(evo, 1), storage.bb_surface_name)
    storage.bb_evolution[biter_force_name] = evo
    set_biter_endgame_modifiers(game.forces[biter_force_name])

    if evo > 1 then
        update_boss_modifiers(biter_force_name, 2, 1)
    end
    if evo > 3.3 then -- 330% evo => 3.3
        storage.max_group_size[biter_force_name] = 50
    elseif evo > 2.3 then
        storage.max_group_size[biter_force_name] = 75
    elseif evo > 1.3 then
        storage.max_group_size[biter_force_name] = 100
    elseif evo > 0.7 then
        storage.max_group_size[biter_force_name] = 200
    end

    storage.bb_threat[biter_force_name] = math_round(storage.bb_threat[biter_force_name] + threat, decimals)
    if Quality.enabled() then
        Quality.feed_flasks(food, flask_amount, tier, biter_force_name)
    end

    if storage.active_special_games['shared_science_throw'] then
        local enemyBitersForceName = enemy_team_of[force_translation[biter_force_name]] .. '_biters'
        game.forces[enemyBitersForceName].set_evolution_factor(
            game.forces[biter_force_name].get_evolution_factor(storage.bb_surface_name),
            storage.bb_surface_name
        )
        storage.bb_evolution[enemyBitersForceName] = storage.bb_evolution[biter_force_name]
        storage.bb_threat_income[enemyBitersForceName] = storage.bb_threat_income[biter_force_name]
        storage.bb_threat[enemyBitersForceName] = math_round(storage.bb_threat[enemyBitersForceName] + threat, decimals)

        if Quality.enabled() then
            Quality.feed_flasks(food, flask_amount, tier, enemyBitersForceName)
        end
    end
end

---@class InventoryContent
---@field name string Name of an item
---@field quality string Name of a quality level
---@field count number Number of items

---Takes specified item with quality from the inventory.
---@param inv LuaInventory Inventory of a player
---@param item string
---@param quality TierEntry
---@return InventoryContent
local function take_from_inventory(inv, item, quality)
    ---@type InventoryContent
    local req = {
        name = item,
        quality = quality.name,
        count = 0,
    }
    req.count = inv.get_item_count(req)
    if req.count ~= 0 then
        inv.remove(req)
    end

    return req
end

---Takes all variants of specified item regardless of it's quality from the inventory.
---@param inv LuaInventory Inventory of a player
---@param item string
---@return InventoryContent[]
local function take_from_inventory_any(inv, item)
    local items = {}
    Quality.for_each_tier(function(_, quality)
        table.insert(items, take_from_inventory(inv, item, quality))
    end)
    return items
end

---Reentrant version of take_from_inventory_any that extends 'content'.
---@param content InventoryContent[]?
---@param inv LuaInventory Inventory of a player
---@param item string
---@return InventoryContent[]
local function take_from_inventory_any_r(content, inv, item)
    local delta = take_from_inventory_any(inv, item)
    if not content then
        return delta
    end

    for _, c in ipairs(delta) do
        table.insert(content, c)
    end

    return content
end

---Get sum value of item count within InventoryContent[]
---@param content InventoryContent[]
---@return number
local function inventory_content_sum_count(content)
    local sum = 0
    for _, c in ipairs(content) do
        sum = sum + c.count
    end

    return sum
end

---Prune entries that are empty (count==0)
---@param content InventoryContent[]
---@return InventoryContent[]
local function inventory_content_prune(content)
    local new = {}
    for _, c in ipairs(content) do
        if c.count ~= 0 then
            table.insert(new, c)
        end
    end

    return new
end

---Generate relevant information about single item being feed in game chat.
---@param content InventoryContent
---@param player LuaPlayer
---@param enemy string
local function inventory_content_print_single(content, player, enemy)
    local color = Player.get_accent_color(player)
    local name = Text.colored(player.name, color)
    local value = food_values[content.name]
    local img = Text.img('item/' .. content.name)
    local text = Text.colored(value.name .. ' juice' .. img, value.color)
    if content.quality ~= 'normal' then
        text = text .. Text.quality(content.quality)
    end

    ---Fills in template with information broadcasted to all players
    ---@param nick string Name of a player
    ---@param amount string|number Number of flasks
    ---@param food string Food being sent
    ---@param force string Name of a force to sent to
    ---@return string Filled template
    local function template_public(nick, amount, food, force)
        if type(amount) == 'number' then
            amount = tostring(amount)
        end

        return table.concat({ nick, ' fed ', amount, ' flasks of ', food, ' to ', force, ' biters!' })
    end

    ---Fills in template with information presented only to single player.
    ---@param amount string Number of flasks
    ---@param food string Food being sent
    ---@param force string Name of a force to sent to
    ---@return string Filled template
    local function template_secret(amount, food, force)
        force = Functions.team_name_with_color(force)
        return table.concat({ 'You fed ', amount, ' flask(s) of ', food, ' to ', force, ' biters!' })
    end

    local amount = Text.font(Text.colored(content.count, { 1, 1, 1 }), 'heading-1')
    if content.count >= 20 then
        local col_enemy = Functions.team_name_with_color(enemy)
        text = Text.colored(template_public(name, amount, text, col_enemy), { 0.9, 0.9, 0.9 })
        game.print(text)

        local flask = value.name
        if Quality.enabled() then
            flask = flask .. ' (' .. content.quality .. ')'
        end

        text = template_public(player.name, content.count, flask, enemy)
        Server.to_discord_bold(text)
    else
        local force = 'the enemy'
        if storage.training_mode then
            force = 'your own'
        end

        text = Text.colored(template_secret(amount, text, force), { 0.98, 0.66, 0.22 })
        player.print(text)
    end
end

---Reentrant helper function that generated relevant information about
---each item variant/group being sent using rich text.
---@param message string String that will grow with each reentry.
---@param content InventoryContent
local function inventory_content_print_multiple_rich_r(message, content)
    local img = Text.img('item/' .. content.name)
    local white = { 1, 1, 1 }
    local entry = Text.font(Text.colored(content.count, white), 'heading-1') .. img
    if Quality.enabled() then
        entry = entry .. Text.quality(content.quality)
    end

    return message .. entry .. ', '
end

---Print information about fed items to discord.
---@param content InventoryContent
---@param player LuaPlayer
---@param enemy string
local function inventory_content_print_multiple_discord(content, player, enemy)
    local item = food_values[content.name].name
    local msg = player.name .. ' fed ' .. content.count .. ' flasks of ' .. item .. ' '
    if Quality.enabled() then
        msg = msg .. '(' .. content.quality .. ') '
    end

    msg = msg .. 'to team ' .. enemy .. ' biters!'
    Server.to_discord_bold(msg)
end

---Generate relevant information about multiple variants of the same item being feed.
---@param content InventoryContent[]
---@param player LuaPlayer
---@param enemy string
local function inventory_content_print_multiple(content, player, enemy)
    local items = ''
    for _, c in ipairs(content) do
        items = inventory_content_print_multiple_rich_r(items, c)
        inventory_content_print_multiple_discord(c, player, enemy)
    end

    local force = Functions.team_name_with_color(enemy)
    local color = Player.get_accent_color(player)
    local nick = Text.colored(player.name, color)
    local msg = nick .. ' fed ' .. items .. 'to ' .. force .. "'s biters!"
    msg = Text.colored(msg, { 0.9, 0.9, 0.9 })
    game.print(msg)
end

---Display relevant information about feeding in game chat.
---@param content InventoryContent[]
---@param player LuaPlayer Player that does the feeding
local function inventory_content_print(content, player)
    local enemy = get_enemy_team_of(player.force.name)
    if not enemy then
        return
    end

    if #content == 1 then
        inventory_content_print_single(content[1], player, enemy)
    else
        inventory_content_print_multiple(content, player, enemy)
    end
end

---Spend available inventory content by sending it to opposite team.
---@param content InventoryContent[]
---@param player LuaPlayer Player that does the feeding
local function inventory_content_spend(content, player)
    local evo, threat = 0, 0
    local space_sci = false
    local p_force = player.force.name
    local b_force = get_enemy_team_of(p_force) .. '_biters'
    for _, c in ipairs(content) do
        evo = storage.bb_evolution[b_force]
        threat = storage.bb_threat[b_force]
        Public.do_raw_feed(c.count, c.name, b_force, Quality.tier_index_by_name(c.quality))
        Public.add_feeding_stats(player, p_force, c.name, c.count, b_force, evo, threat, c.quality)
        if c.name == 'space-science-pack' then
            space_sci = true
        end
    end

    if space_sci then
        storage.spy_fish_timeout[p_force] = game.tick + 99999999
    end
end

--- @param player LuaPlayer
--- @param food string
function Public.feed_biters_from_inventory(player, food)
    local tick = Functions.get_ticks_since_game_start()
    if storage.active_special_games['captain_mode'] then
        tick = game.ticks_played
    end
    if tick <= storage.difficulty_votes_timeout then
        player.print('Please wait for voting to finish before feeding')
        return
    end

    local inv = player.character.get_main_inventory()
    if not inv then
        return
    end

    local content = take_from_inventory_any(inv, food)
    content = inventory_content_prune(content)
    local total = inventory_content_sum_count(content)
    if total == 0 then
        local msg = 'You have no ' .. food_values[food].name .. ' flask '
        if Quality.enabled() then
            msg = msg .. 'of any quality '
        end
        msg = msg .. 'in your inventory.'
        player.print(Text.colored(msg, { 0.98, 0.66, 0.22 }))
        return
    end

    inventory_content_print(content, player)
    inventory_content_spend(content, player)
end

--- @param player LuaPlayer
--- @param button defines.mouse_button_type
function Public.feed_biters_mixed_from_inventory(player, button)
    local tick = Functions.get_ticks_since_game_start()
    if storage.active_special_games['captain_mode'] then
        tick = game.ticks_played
    end
    if tick <= storage.difficulty_votes_timeout then
        player.print('Please wait for voting to finish before feeding')
        return
    end

    ---Reverse elements in an array.
    ---@param arr table
    local function reverse(arr)
        local i = 1
        local new = {}
        for j = #arr, 1, -1 do
            new[i] = arr[j]
            i = i + 1
        end

        return new
    end

    local food = Table.keys(tables.food_values)
    if button == defines.mouse_button_type.right then
        food = reverse(food)
    end

    local inv = player.character.get_main_inventory()
    if not inv then
        return
    end

    local content = nil
    for _, v in ipairs(food) do
        content = take_from_inventory_any_r(content, inv, v)
    end
    content = inventory_content_prune(content)

    local total = inventory_content_sum_count(content)
    if total == 0 then
        local msg = 'You have no flasks in your inventory'
        msg = Text.colored(msg, { 0.98, 0.66, 0.22 })
        player.print(msg)
        return
    end

    inventory_content_print(content, player)
    inventory_content_spend(content, player)
end

local function calc_send(cmd)
    local player
    if cmd.player_index then
        player = game.get_player(cmd.player_index)
    end
    local player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    local result = safe_wrap_with_player_print(
        player,
        FeedingCalculations.calc_send_command,
        cmd.parameter,
        storage.difficulty_vote_value,
        storage.bb_evolution,
        storage.max_reanim_thresh,
        storage.training_mode,
        player_count,
        player
    )
    if not result then
        return
    end
    if player then
        player.print(result)
    else
        game.print(result)
    end
end

commands.add_command('calc-send', 'Calculate the impact of sending science', calc_send)

return Public
