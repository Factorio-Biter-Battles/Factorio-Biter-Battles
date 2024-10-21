local TeamStatsCollect = {}

local functions = require('maps.biter_battles_v2.functions')
local tables = require('maps.biter_battles_v2.tables')
local event = require('utils.event')
local difficulty_vote = require('maps.biter_battles_v2.difficulty_vote')

---@class ForceStats
---@field final_evo? number
---@field peak_threat? number
---@field lowest_threat? number
-- player_ticks / ticks = average players
---@field player_ticks? integer
---@field total_players? integer
---@field max_players? integer
---@field food table<string, {first_at?: integer, produced: number, consumed: number, sent: number}>
---@field items table<string, {first_at?: integer, produced?: number, consumed?: number, placed?: number, lost?: number, kill_count?: number}>
---@field damage_types table<string, {kills?: integer, damage?: number}>

---@class TeamStats
---@field forces table<string, ForceStats>
---@field ticks integer?
---@field won_by_team string?
---@field difficulty string?
---@field difficulty_value number?

---@type {item: string, placed?: boolean, space_after?: boolean, hide_by_default?: boolean}[]
TeamStatsCollect.items_to_show_summaries_of = {
    { item = 'coal' },
    { item = 'stone' },
    { item = 'iron-plate' },
    { item = 'copper-plate' },
    { item = 'steel-plate', space_after = true },

    { item = 'electronic-circuit', hide_by_default = true },
    { item = 'advanced-circuit', hide_by_default = true },
    { item = 'processing-unit', space_after = true, hide_by_default = true },

    { item = 'rocket-part', hide_by_default = true },
    { item = 'rocket-fuel', hide_by_default = true },
    { item = 'low-density-structure', space_after = true, hide_by_default = true },

    { item = 'electric-mining-drill', placed = true },
    { item = 'boiler', placed = true, hide_by_default = true },
    { item = 'steam-engine', placed = true, hide_by_default = true },
    { item = 'fast-transport-belt', placed = true, hide_by_default = true },
    { item = 'transport-belt', placed = true, space_after = true },

    { item = 'roboport', placed = true },
    { item = 'construction-robot' },
    { item = 'nuclear-reactor', placed = true, space_after = true },

    { item = 'stone-wall', placed = true },
    { item = 'gun-turret', placed = true },
    { item = 'flamethrower-turret', placed = true },
    { item = 'laser-turret', placed = true },
}

TeamStatsCollect.damage_render_info = {
    {
        'physical',
        'Physical [item=gun-turret][item=submachine-gun][item=defender-capsule]',
        'Also [item=shotgun-shell][item=cannon-shell] etc',
    },
    {
        'explosion',
        'Explosion [item=grenade]',
        'Also [item=explosive-cannon-shell][item=explosive-rocket][item=cluster-grenade] etc',
    },
    { 'laser', 'Laser [item=laser-turret]' },
    { 'fire', 'Fire [item=flamethrower-turret]', 'Also [item=flamethrower]' },
    { 'electric', 'Electric [item=discharge-defense-equipment][item=destroyer-capsule]' },
    { 'poison', 'Poison [item=poison-capsule]' },
    { 'impact', 'Impact [item=locomotive][item=car][item=tank]' },
}

local tracked_inventories = {
    ['assembling-machine'] = true,
    ['boiler'] = true,
    ['car'] = true,
    ['cargo-wagon'] = true,
    ['character-corpse'] = true,
    ['construction-robot'] = true,
    ['container'] = true,
    ['furnace'] = true,
    ['inserter'] = true,
    ['lab'] = true,
    ['logistic-container'] = true,
    ['logistic-robot'] = true,
    ['reactor'] = true,
    ['roboport'] = true,
    ['rocket-silo'] = true,
    ['spider-vehicle'] = true,
}

local force_name_map = {
    north_biters = 'north',
    north_biters_boss = 'north',
    south_biters = 'south',
    south_biters_boss = 'south',
}

local health_factor_map = {
    north_biters = 1,
    north_biters_boss = 20,
    south_biters = 1,
    south_biters_boss = 20,
}

local function update_teamstats()
    local team_stats = storage.team_stats
    local tick = functions.get_ticks_since_game_start()
    if team_stats.won_by_team then
        return
    end
    team_stats.won_by_team = storage.bb_game_won_by_team
    team_stats.difficulty = difficulty_vote.short_difficulty_name()
    team_stats.difficulty_value = storage.difficulty_vote_value
    if tick == 0 then
        return
    end
    local prev_ticks = team_stats.ticks or 0
    team_stats.ticks = tick
    local total_players = { north = 0, south = 0 }
    for _, force_name in pairs(storage.chosen_team) do
        total_players[force_name] = (total_players[force_name] or 0) + 1
    end
    for _, force_name in ipairs({ 'north', 'south' }) do
        local force = game.forces[force_name]
        local biter_force_name = force_name .. '_biters'
        local force_stats = team_stats.forces[force_name]
        local threat = storage.bb_threat[biter_force_name]
        force_stats.final_evo = storage.bb_evolution[biter_force_name]
        force_stats.peak_threat = (force_stats.peak_threat and math.max(threat, force_stats.peak_threat) or threat)
        force_stats.lowest_threat = (
            force_stats.lowest_threat and math.min(threat, force_stats.lowest_threat) or threat
        )
        force_stats.total_players = total_players[force_name]
        force_stats.player_ticks = (force_stats.player_ticks or 0) + #force.connected_players * (tick - prev_ticks)
        force_stats.max_players = math.max(force_stats.max_players or 0, #force.connected_players)
        local item_prod = force.get_item_production_statistics(storage.bb_surface_name)
        --local item_prod_inputs = item_prod.input_counts
        --log(serpent.line(item_prod_inputs))
        local build_stat = force.get_entity_build_count_statistics(storage.bb_surface_name)
        local kill_stat = force.get_kill_count_statistics(storage.bb_surface_name)
        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            local item = item_info.item
            local item_stat = force_stats.items[item]
            if not item_stat then
                item_stat = {}
                force_stats.items[item] = item_stat
            end
            item_stat.produced = item_prod.get_input_count(item)
            item_stat.consumed = item_prod.get_output_count(item)
            if not item_stat.first_at and item_stat.produced and item_stat.produced > 0 then
                item_stat.first_at = tick
            end
            if item_info.placed then
                local item_build_stat = build_stat.get_input_count(item)
                if (item_build_stat or 0) > 0 then
                    -- we subtract out the number deconstructed, so this is really a max-net-placed-over-time
                    local net_built = item_build_stat - build_stat.get_output_count(item)
                    item_stat.placed = math.max(0, item_stat.placed or 0, net_built)
                end
                local kill_count = kill_stat.get_output_count(item)
                if (kill_count or 0) > 0 then
                    item_stat.kill_count = kill_count
                end
            end
        end
        local science_logs = global['science_logs_total_' .. force_name]
        for idx, info in ipairs(tables.food_long_and_short) do
            local item = info.long_name
            local food_stat = force_stats.food[item]
            if not food_stat then
                food_stat = {}
                force_stats.food[item] = food_stat
            end
            food_stat.sent = science_logs and science_logs[idx] or 0
            food_stat.produced = item_prod.get_input_count(item)
            food_stat.consumed = item_prod.get_output_count(item)
            if not food_stat.first_at and (food_stat.produced or 0) > 0 then
                food_stat.first_at = tick
            end
        end
    end

    local last_print = storage.last_teamstats_print_at or 0
    if tick - last_print > 5 * 60 * 60 then
        log({ '', '[TEAMSTATS-PERIODIC]', game.table_to_json(team_stats) })
        storage.last_teamstats_print_at = tick
    end
end

---@param max number
---@return number
local function random_item_quantity(max)
    if math.random() < 0.3 then
        return 0
    end
    return math.floor(math.exp(math.random() * math.log(max)))
end

---@param num number
---@return number
local function random_item_subset(num)
    if math.random() < 0.2 then
        return 0
    end
    return math.floor(math.exp(math.random() * math.log(num)))
end

---@return TeamStats
function TeamStatsCollect.compute_stats()
    if not storage.team_stats_use_fake_data then
        update_teamstats()
        return storage.team_stats
    end

    -- In the (very uncommon) case of team_stats_use_fake_data being set, we will generate fake data for
    -- testing the UI.
    local teams = { 'north', 'south' }
    ---@type TeamStats
    local stats = { ticks = 110 * 3600, won_by_team = teams[math.random(1, 3)], forces = {} }
    for idx, force_name in ipairs({ 'north', 'south' }) do
        ---@type ForceStats
        local force_stats = {
            final_evo = idx * 0.55,
            peak_threat = idx * 100000,
            lowest_threat = idx * -10000,
            total_players = idx * 20,
            max_players = idx * 10,
            player_ticks = math.random() * stats.ticks * 10,
            food = {
                ['automation-science-pack'] = {
                    first_at = idx * 10 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['logistic-science-pack'] = {
                    first_at = idx * 20 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['military-science-pack'] = {
                    first_at = idx * 30 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['chemical-science-pack'] = {
                    first_at = idx * 40 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['production-science-pack'] = {
                    first_at = idx * 50 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['utility-science-pack'] = {
                    first_at = idx * 60 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
                ['space-science-pack'] = {
                    first_at = idx * 70 * 3600,
                    produced = idx * 1000,
                    consumed = idx * 500,
                    sent = idx * 200,
                },
            },
            items = {},
            damage_types = {},
        }
        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            local item_stat = {
                first_at = math.floor(math.random() * 100 * 3600),
                produced = random_item_quantity(1000000),
            }
            force_stats.items[item_info.item] = item_stat
            item_stat.consumed = random_item_subset(item_stat.produced)
            if item_info.placed then
                item_stat.placed = random_item_subset(item_stat.produced - item_stat.consumed)
            end
        end
        for _, damage_info in ipairs(TeamStatsCollect.damage_render_info) do
            if math.random() < 0.5 then
                force_stats.damage_types[damage_info[1]] = {
                    kills = random_item_quantity(10000),
                    damage = random_item_quantity(10000000),
                }
            end
        end
        stats.forces[force_name] = force_stats
    end
    return stats
end

-- Tracks items lost by each team and damage inflicted to enemy biters
---@param event EventData.on_entity_died
local function on_entity_died(event)
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    local entity_force_name = (entity.force and entity.force.name) or ''

    -- North/South entities
    if entity_force_name == 'north' or entity_force_name == 'south' then
        local item_stats = storage.team_stats.forces[entity_force_name].items
        if not item_stats then
            item_stats = {}
            storage.team_stats.forces[entity_force_name].items = item_stats
        end
        if entity.type == 'construction-robot' or entity.type == 'logistic-robot' then
            item_stats[entity.name] = item_stats[entity.name] or {}
            item_stats[entity.name].kill_count = (item_stats[entity.name].kill_count or 0) + 1
        end
        if tracked_inventories[entity.type] then
            for item, amount in pairs(functions.get_entity_contents(entity)) do
                item_stats[item] = item_stats[item] or {}
                item_stats[item].lost = (item_stats[item].lost or 0) + amount
            end
        end
        return
    end

    -- North/South biters
    if not event.damage_type then
        return
    end
    local health_factor = health_factor_map[entity_force_name]
    local force_name = force_name_map[entity_force_name]
    if not health_factor or not force_name then
        return
    end

    health_factor = health_factor * storage.biter_health_factor[game.forces[force_name .. '_biters'].index]

    local force_stats = storage.team_stats.forces[force_name]
    local damage_stats = force_stats.damage_types[event.damage_type.name]
    if not damage_stats then
        damage_stats = { kills = 0, damage = 0 }
        force_stats.damage_types[event.damage_type.name] = damage_stats
    end
    damage_stats.kills = damage_stats.kills + 1
    -- This is somewhat inaccurate, because biter_health_factor might be different
    -- now than when the biter was spawned, but it is close enough for me.
    damage_stats.damage = damage_stats.damage + entity.prototype.max_health * health_factor
end

-- We could theoretically collect just once per minute, but this collection will not be
-- aligned to game time.  Thus we collect every 16 seconds instead, which will make the
-- numbers a bit more accurate (i.e. off by at most 16 seconds, instead of off by at
-- most 60 seconds).
-- I use (60*16-1) rather than 60*16 just to avoid doing extra work on per-second boundaries,
-- which are quite common in our code.
event.on_nth_tick(60 * 16 - 1, update_teamstats)

event.add(defines.events.on_entity_died, on_entity_died)

return TeamStatsCollect
