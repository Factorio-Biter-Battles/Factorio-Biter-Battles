local _TEST = storage['_TEST'] or false

local gui = nil
if not _TEST then
    gui = require('utils.gui')
end

local color = require('utils.color_presets')
local food_values = require('maps.biter_battles_v2.tables').food_values
local math_log = math.log
local math_random = math.random
local string_find = string.find
local string_sub = string.sub
local mod = {}

if not _TEST then
    ---Adds quality icon into GUI.
    function mod.update_feature_flag(player)
        if not mod.enabled() then
            return
        end

        local t = gui.get_top_element(player, 'bb_feature_flags')
        local button = t.add({
            type = 'sprite',
            name = 'quality_gui',
            sprite = 'utility/any_quality',
        })
        button.style.maximal_height = 25
        button.tooltip = 'Quality enabled!'
    end

    ---Handles state when player toggles quality mod in comfy panel.
    function mod.on_gui_switch_state_changed(event)
        local p = game.get_player(event.player_index)
        local s = game.surfaces[storage.bb_surface_name]
        if event.element.switch_state == 'left' then
            storage.comfy_panel_config.quality_scheduled = true
            s.print('Quality mod enabled by ' .. p.name, { color = color.yellow })
        else
            storage.comfy_panel_config.quality_scheduled = false
            s.print('Quality mod disabled by ' .. p.name, { color = color.yellow })
        end
    end
end

---@class TierEntry
---@field name string Name of quality.
---@field multiplier integer Multiplier associated with given quality which impacts chance calculation
---@field level integer Integer that directly maps to LuaQualityPrototype.

---@type TierEntry[]
mod.TIERS = {
    {
        name = 'normal',
        multiplier = 1,
        level = 0,
    },
    {
        name = 'uncommon',
        multiplier = 1.5,
        level = 1,
    },
    {
        name = 'rare',
        multiplier = 2.25,
        level = 2,
    },
    {
        name = 'epic',
        multiplier = 3.5,
        level = 3,
    },
    {
        name = 'legendary',
        multiplier = 5,
        level = 5,
    },
}

---Maps to normal quality tier. Useful when trying to write code that is both
---compatible with vanilla and quality mod.
mod.TIER_DEFAULT = 1

---Utility function to find entry position in mod.TIERS by level.
---@param level integer
---@return integer?
function mod.tier_index_by_level(level)
    for i, v in ipairs(mod.TIERS) do
        if v.level == level then
            return i
        end
    end

    return nil
end

---Utility function to find entry position in mod.TIERS by name.
---@param name string
---@return integer?
function mod.tier_index_by_name(name)
    for i, v in ipairs(mod.TIERS) do
        if v.name == name then
            return i
        end
    end

    return nil
end

---Cycle through each available quality tier and execute
---function
---@param fn fun(idx: integer, entry: TierEntry)
function mod.for_each_tier(fn)
    local max = mod.max_tier()
    for i = 1, max do
        fn(i, mod.TIERS[i])
    end
end

---Get integers of available quality tiers. In base game, only normal quality is available.
---@return integer Integer of quality tiers
function mod.max_tier()
    if mod.enabled() then
        return #mod.TIERS
    end

    return 1
end

---Roll a dice for selected biter quality and force.
---@param tier integer Selected quality of biter.
---@param force string Biter force name.
---@return boolean If quality biter was rolled or not.
function mod.roll(tier, force)
    local c = mod.chance(tier, force)
    local r = math_random(0, 100)
    return r <= (c * 100)
end

---Calculate normalized probability based on supplied data
---@param chances number[] Holds chance of roll at each level
---@return number[] List of probabilities
function mod.test_probabilities(chances)
    ---Probabilities
    ---@type number[]
    local probs = {}
    local sum = 0
    local max = #chances
    ---Current probability.
    local curr = 1.0
    for i = max, 1, -1 do
        local chance = chances[i]
        local p = curr * chance
        table.insert(probs, p)
        sum = sum + p
        curr = curr * (1 - chance)
    end

    local final = {}
    local j = max
    for i = 1, max do
        final[j] = (probs[i] / sum) * 100
        j = j - 1
    end

    return final
end

---Collect all chances for given force
---@param force string Biter force name.
---@return number[] List of chances.
function mod.collect_chances(force)
    local chances = {}
    local max = mod.max_tier()
    for i = max, 1, -1 do
        chances[i] = mod.chance(i, force)
    end

    return chances
end

---Create a copy of internal values used for chance computation.
---@param force string Biter force name.
---@return integer[]
function mod.collect_values(force)
    return table.deepcopy(storage.quality.value[force])
end

---Gets normalized probability to roll given level.
---@param force string Biter force name.
---@return number[] List of probabilities
function mod.probabilties(force)
    return mod.test_probabilities(mod.collect_chances(force))
end

---Applies scaling formula on accumulated value of fed flasks so far.
---@param value integer Accumulated value from past feeding.
---@return integer Chance to roll biter in range of [0.0 - 1.0]
local function compute_chance(value)
    local chance = math_log(1.1 * value + 1) / math_log(100)
    if chance > 1.0 then
        chance = 1.0
    end

    return chance
end

---Use raw intermediate values to calculate probabilities.
---@param values integer[] Intermediate values.
---@return number[] List of probabilities
function mod.dry_test_probabilities(values)
    local chances = {}
    for i, v in ipairs(values) do
        chances[i] = compute_chance(v)
    end

    return mod.test_probabilities(chances)
end

---Roll chance of selected biter quality within given force.
---@param tier integer Selected quality of biter.
---@param force string Biter force name.
---@return integer Chance to roll biter in range of [0.0 - 1.0]
function mod.chance(tier, force)
    if string_find(force, '_boss') then
        force = string_sub(force, 1, -6)
    end

    return compute_chance(storage.quality.value[force][tier])
end

---Does the same as feed_flasks, but result is not stored anywhere.
---@param value integer Accumulated value from past feeding.
---@param name string Name of the flask.
---@param amount integer Amount of flasks.
---@param diff_value integer Difficulty modifier.
---@return integer New update value
function mod.dry_feed_flasks(value, name, amount, diff_value)
    return value + (food_values[name].value * diff_value * amount)
end

---Updates the permament chance of rolling quality biters.
---@param name string Name of the flask.
---@param amount integer Amount of flasks.
---@param tier integer Quality of flasks.
---@param force string Name of biter force to which new chance is applied.
function mod.feed_flasks(name, amount, tier, force)
    local value = storage.quality.value[force][tier]
    storage.quality.value[force][tier] = mod.dry_feed_flasks(value, name, amount, storage.difficulty_vote_value)
end

---Resets a recipe in assembling machine if it's set to satellite
local function try_reset_recipe(e)
    local recipe = e.get_recipe()
    if not (recipe and recipe.name == 'satellite') then
        return
    end

    local surface = game.surfaces[storage.bb_surface_name]
    local items = e.set_recipe(nil)
    for _, stack in ipairs(items) do
        surface.spill_item_stack({
            position = e.position,
            stack = stack,
        })
    end
end

---Inspects continuously all assemblers for satellite recipe. If such is
---detected in asm2 or asm3 then it's cleared. We do this to prevent placing
---quality modules into them as gambling for quality satellite without quality
---intermediates might be too unfair to opposite team.
---@param event table
function mod.inspect_satellite(event)
    if not mod.enabled() then
        return
    end

    if event.tick % 240 ~= 0 then
        return
    end

    for name, f in pairs(game.forces) do
        local entities = storage.quality.assembling_machines[name]
        if not (f.technologies['quality-module'].researched and entities) then
            goto inspect_satellite_cont
        end

        for _, e in pairs(entities) do
            try_reset_recipe(e)
        end

        ::inspect_satellite_cont::
    end
end

---Remove assembling machines from tracking.
---@param event table
function mod.remove_assembling_machine(event)
    if not mod.enabled() then
        return
    end

    local entity = event.entity
    if not entity or not entity.valid then
        return
    end

    if entity.type ~= 'assembling-machine' then
        return
    end

    if entity.name == 'assembling-machine-1' then
        return
    end

    local tbl = storage.quality.assembling_machines[entity.force.name]
    tbl[entity.unit_number] = nil
end

---Add assembling machines for tracking purposes.
---@param event table
function mod.track_assembling_machine(event)
    if not mod.enabled() then
        return
    end

    local entity = event.entity
    if not entity or not entity.valid then
        return
    end

    if entity.type ~= 'assembling-machine' then
        return
    end

    if entity.name == 'assembling-machine-1' then
        return
    end

    ---In case assembling-machine-1 is replaced, it will retain
    ---progress which will carry over to higher tier machine. This prevents
    ---exploiting interval between checks for satellite recipe.
    try_reset_recipe(entity)
    local tbl = storage.quality.assembling_machines[entity.force.name]
    tbl[entity.unit_number] = entity
end

---Initialize data related to quality mod. Meant to be called on each map reset.
function mod.init()
    ---Namespace that holds all variables related to quality.
    storage.quality = {}
    storage.quality.enabled = storage.comfy_panel_config.quality_scheduled

    ---Used for tracking assembling machines placed by players. We're going to
    ---inspect those later to check if any of those have satellite recipe set.
    ---Only assembling-machine-2 or higher are tracked.
    ---@type { [string]: { [integer]: LuaEntity } }
    storage.quality.assembling_machines = {
        north = {},
        south = {},
    }

    ---Stores basic accumulated value of all feed flasks. This value is used
    ---later to calculate roll chance of higher quality biters on-demand.
    ---@type { [string]: integer[] }
    storage.quality.value = {
        north_biters = {},
        south_biters = {},
    }

    for i = 1, #mod.TIERS do
        storage.quality.value.north_biters[i] = 0.0
        storage.quality.value.south_biters[i] = 0.0
    end

    -- 100% chance to get common biters
    storage.quality.value.north_biters[1] = 999999
    storage.quality.value.south_biters[1] = 999999
end

---Setup technology tree. Meant to be called on each map reset.
---@param force LuaForce
function mod.set_technologies(force)
    local technologies = force.technologies
    if mod.enabled() then
        technologies['quality-module'].enabled = true
        technologies['quality-module-2'].enabled = true
        technologies['quality-module-3'].enabled = true
        technologies['recycling'].enabled = true
        technologies['epic-quality'].enabled = true
        technologies['legendary-quality'].enabled = true
    elseif mod.installed() then
        technologies['quality-module'].enabled = false
        technologies['quality-module-2'].enabled = false
        technologies['quality-module-3'].enabled = false
        technologies['recycling'].enabled = false
        technologies['epic-quality'].enabled = false
        technologies['legendary-quality'].enabled = false
    end
end

---@return boolean
function mod.installed()
    return script.feature_flags.quality
end

---@return boolean
function mod.scheduled()
    return storage.comfy_panel_config.quality_scheduled
end

---@return boolean
function mod.enabled()
    return storage.quality.enabled
end

return mod
