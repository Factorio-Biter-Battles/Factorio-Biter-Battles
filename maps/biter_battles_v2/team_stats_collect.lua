
local TeamStatsCollect = {}

local functions = require 'maps.biter_battles_v2.functions'
local tables = require 'maps.biter_battles_v2.tables'
local event = require 'utils.event'
local difficulty_vote = require 'maps.biter_battles_v2.difficulty_vote'

---@class ForceStats
---@field final_evo? number
---@field peak_threat? number
---@field lowest_threat? number
-- player_ticks / ticks = average players
---@field player_ticks? integer
---@field total_players? integer
---@field max_players? integer
---@field food table<string, {first_at?: integer, produced: number, consumed: number, sent: number}>
---@field items table<string, {first_at?: integer, produced?: number, placed?: number, lost?: number}>
---@field damage_types table<string, {kills?: integer, damage?: number}>

---@class TeamStats
---@field forces table<string, ForceStats>
---@field ticks integer?
---@field won_by_team string?
---@field difficulty string?
---@field difficulty_value number?

TeamStatsCollect.items_to_show_summaries_of = {
    {item = "coal"},
    {item = "stone"},
    {item = "iron-plate"},
    {item = "copper-plate"},
    {item = "steel-plate", space_after = true},

    {item = "electronic-circuit"},
    {item = "advanced-circuit"},
    {item = "processing-unit", space_after = true},

    {item = "transport-belt", placed = true},
    {item = "fast-transport-belt", placed = true, space_after = true},

    {item = "roboport", placed = true},
    {item = "construction-robot"},
    {item = "nuclear-reactor", placed = true, space_after = true},

    {item = "stone-wall", placed = true},
    {item = "gun-turret", placed = true},
    {item = "flamethrower-turret", placed = true},
    {item = "laser-turret", placed = true},
}

TeamStatsCollect.damage_render_info = {
    {"physical", "Physical [item=gun-turret][item=submachine-gun][item=defender-capsule]", "Also [item=shotgun-shell][item=cannon-shell] etc"},
    {"explosion", "Explosion [item=grenade]", "Also [item=explosive-cannon-shell][item=explosive-rocket][item=cluster-grenade] etc"},
    {"laser", "Laser [item=laser-turret]"},
    {"fire", "Fire [item=flamethrower-turret]", "Also [item=flamethrower]"},
    {"electric", "Electric [item=discharge-defense-equipment][item=destroyer-capsule]"},
    {"poison", "Poison [item=poison-capsule]"},
    {"impact", "Impact [item=locomotive][item=car][item=tank]"},
}

local function update_teamstats()
    local team_stats = global.team_stats
    local tick = functions.get_ticks_since_game_start()
    if team_stats.won_by_team then return end
    team_stats.won_by_team = global.bb_game_won_by_team
    team_stats.difficulty = difficulty_vote.short_difficulty_name()
    team_stats.difficulty_value = global.difficulty_vote_value
    if tick == 0 then return end
    local prev_ticks = team_stats.ticks or 0
    team_stats.ticks = tick
    local total_players = {north = 0, south = 0}
    for _, force_name in pairs(global.chosen_team) do
        total_players[force_name] = (total_players[force_name] or 0) + 1
    end
    for _, force_name in ipairs({"north", "south"}) do
        local force = game.forces[force_name]
        local biter_force_name = force_name .. "_biters"
        local force_stats = team_stats.forces[force_name]
        local threat = global.bb_threat[biter_force_name]
        force_stats.final_evo = global.bb_evolution[biter_force_name]
        force_stats.peak_threat = (force_stats.peak_threat and math.max(threat, force_stats.peak_threat) or threat)
        force_stats.lowest_threat = (force_stats.lowest_threat and math.min(threat, force_stats.lowest_threat) or threat)
        force_stats.total_players = total_players[force_name]
        force_stats.player_ticks = (force_stats.player_ticks or 0) + #force.connected_players * (tick - prev_ticks)
        force_stats.max_players = math.max(force_stats.max_players or 0, #force.connected_players)
        local item_prod = force.item_production_statistics
        --local item_prod_inputs = item_prod.input_counts
        --log(serpent.line(item_prod_inputs))
        local build_stat = force.entity_build_count_statistics
        local kill_stat = force.kill_count_statistics
        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            local item_stat = force_stats.items[item_info.item]
            if not item_stat then
                item_stat = {}
                force_stats.items[item_info.item] = item_stat
            end
            item_stat.produced = item_prod.get_input_count(item_info.item)
            if not item_stat.first_at and item_stat.produced and item_stat.produced > 0 then
                item_stat.first_at = tick
            end
            if item_info.placed then
                local item_build_stat = build_stat.get_input_count(item_info.item)
                if (item_build_stat or 0) > 0 then
                    -- we subtract out the number deconstructed, so this is really a max-net-placed-over-time
                    local net_built = item_build_stat - build_stat.get_output_count(item_info.item)
                    item_stat.placed = math.max(0, item_stat.placed or 0, net_built)
                end
                local kill_count = kill_stat.get_output_count(item_info.item)
                if (kill_count or 0) > 0 then
                    item_stat.lost = kill_count
                end
            end
        end
        local science_logs = global["science_logs_total_" .. force_name]
        for idx, info in ipairs(tables.food_long_and_short) do
            local food_stat = force_stats.food[info.long_name]
            if not food_stat then
                food_stat = {}
                force_stats.food[info.long_name] = food_stat
            end
            food_stat.sent = science_logs and science_logs[idx] or 0
            food_stat.produced = item_prod.get_input_count(info.long_name)
            food_stat.consumed = item_prod.get_output_count(info.long_name)
            if not food_stat.first_at and (food_stat.produced or 0) > 0 then
                food_stat.first_at = tick
            end
        end
    end
end

---@return TeamStats
function TeamStatsCollect.compute_stats()
    if not global.team_stats_use_fake_data then
        update_teamstats()
        return global.team_stats
    end

    -- In the (very uncommon) case of team_stats_use_fake_data being set, we will generate fake data for
    -- testing the UI.
    local teams = {"north", "south"}
    ---@type TeamStats
    local stats = { ticks = 110*3600, won_by_team = teams[math.random(1, 3)], forces = {} }
    for idx, force_name in ipairs({"north", "south"}) do
        ---@type ForceStats
        local force_stats = {
            final_evo = idx * 0.55,
            peak_threat = idx * 100000,
            lowest_threat = idx * -10000,
            total_players = idx * 20,
            max_players = idx * 10,
            player_ticks = math.random() * stats.ticks * 10,
            food = {
                ["automation-science-pack"] = {first_at = idx * 10*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["logistic-science-pack"] = {first_at = idx * 20*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["military-science-pack"] = {first_at = idx * 30*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["chemical-science-pack"] = {first_at = idx * 40*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["production-science-pack"] = {first_at = idx * 50*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["utility-science-pack"] = {first_at = idx * 60*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
                ["space-science-pack"] = {first_at = idx * 70*3600, produced = idx * 1000, consumed = idx * 500, sent = idx * 200},
            },
            items = {},
            damage_types = {},
        }
        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            force_stats.items[item_info.item] = {
                first_at = math.floor(math.random() * 100*3600),
                produced = math.random(1, 10000000),
            }
            if item_info.placed then
                force_stats.items[item_info.item].placed = math.random(1, force_stats.items[item_info.item].produced)
            end
        end
        for _, damage_info in ipairs(TeamStatsCollect.damage_render_info) do
            if math.random() < 0.5 then
                force_stats.damage_types[damage_info[1]] = {
                    kills = math.random(1, 1000),
                    damage = math.random(1, 10000000),
                }
            end
        end
        stats.forces[force_name] = force_stats
    end
    return stats
end

---@param event EventData.on_entity_died
local function on_entity_died(event)
    local entity = event.entity
    if not entity.valid then return end
    if not event.damage_type then return end
    local force_name, biter_force_name
    local health_factor = 1
    if entity.force.name == "north_biters" or entity.force.name == "north_biters_boss" then
        force_name = "north"
        biter_force_name = "north_biters"
        if entity.force.name == "north_biters_boss" then health_factor = health_factor * 20 end
    elseif entity.force.name == "south_biters" or entity.force.name == "south_biters_boss" then
        force_name = "south"
        biter_force_name = "south_biters"
        if entity.force.name == "south_biters_boss" then health_factor = health_factor * 20 end
    else
        return
    end
    health_factor = health_factor / (1 - global.reanim_chance[game.forces[biter_force_name].index] / 100)

    local force_stats = global.team_stats.forces[force_name]
    local damage_stats = force_stats.damage_types[event.damage_type.name]
    if not damage_stats then
        damage_stats = {kills = 0, damage = 0}
        force_stats.damage_types[event.damage_type.name] = damage_stats
    end
    damage_stats.kills = damage_stats.kills + 1
    -- This is somewhat inaccurate, because revive% might be different
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
