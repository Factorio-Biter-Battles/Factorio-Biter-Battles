local _TEST = storage['_TEST'] or false

local gui = nil
local gui_style = nil
if not _TEST then
    gui = require('utils.gui')
    gui_style = require('utils.utils').gui_style
end

local color = require('utils.color_presets')
local food_values = require('maps.biter_battles_v2.tables').food_values
local mod = {}

if not _TEST then
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

-- level is directly mappable to LuaQualityPrototype::level
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

function mod.tier_index_by_level(level)
    for i, v in ipairs(mod.TIERS) do
        if v.level == level then
            return i
        end
    end

    return nil
end

function mod.tier_index_by_name(name)
    for i, v in ipairs(mod.TIERS) do
        if v.name == name then
            return i
        end
    end

    return nil
end

function mod.tier_by_level(level)
    return mod.TIERS[mod.tier_index_by_level(level)]
end

function mod.available_tiers()
    if mod.enabled() then
        return #mod.TIERS
    end

    return 1
end

local function button_tooltip(tier)
    local tooltip = 'Quality of food\nMutagen multiplier ' .. mod.TIERS[tier].multiplier .. 'x'
    if tier > 1 then
        tooltip = tooltip .. '\nBoosts chance of ' .. mod.TIERS[tier].name .. ' biters'
    end

    return tooltip .. '\nLMB - Increase quality, RMB - Lower quality'
end

function mod.on_gui_click(event)
    local player = game.players[event.player_index]
    local tier = storage.quality_feed_selected[player.index]
    if event.button == defines.mouse_button_type.left then
        if tier == #mod.TIERS then
            return
        end

        tier = tier + 1
    elseif event.button == defines.mouse_button_type.right then
        if tier == 1 then
            return
        end

        tier = tier - 1
    end

    storage.quality_feed_selected[player.index] = tier
    local sprite = 'quality/' .. mod.TIERS[tier].name
    event.element.sprite = sprite
    event.element.tooltip = button_tooltip(tier)
end

function mod.add_feeding_button(player, parent)
    if not mod.enabled() then
        return
    end

    local tier = storage.quality_feed_selected[player.index]
    if not tier then
        tier = 1
        storage.quality_feed_selected[player.index] = tier
    end

    local f = parent.add({
        type = 'sprite-button',
        name = 'quality_feed',
        sprite = 'quality/' .. mod.TIERS[tier].name,
        style = 'slot_button',
        tooltip = button_tooltip(tier),
    })
    gui_style(f, {
        padding = 0,
    })
end

function mod.multiplier(player)
    local id = storage.quality_feed_selected[player.index]
    return mod.TIERS[id].multiplier
end

function mod.selected_by(player)
    -- If we're just starting, return default value.
    local id = storage.quality_feed_selected[player.index]
    if not id then
        return 1
    end

    return id
end

function mod.roll(tier, force)
    local c = mod.chance(tier, force)
    local r = storage.random_generator(0, 100)
    return r <= (c * 100)
end

local function compute_chance(value)
    local chance = math.log(1.1 * value + 1) / math.log(100)
    if chance > 1.0 then
        chance = 1.0
    end

    return chance
end

function mod.chance(tier, force)
    if string.find(force, '_boss') then
        force = string.sub(force, 1, -6)
    end

    return compute_chance(storage.quality_value[force][tier])
end

function mod.dry_feed_flasks(value, name, amount, difficulty_vote_value)
    return value + (food_values[name].value * difficulty_vote_value * amount)
end

function mod.chance_difference(value, tier, force)
    value = compute_chance(value + storage.quality_value[force][tier])
    local curr = compute_chance(storage.quality_value[force][tier])
    if value > 1.0 then
        value = 1.0 - curr
    else
        value = value - curr
    end

    return value
end

-- Updates the permament chance of quality biters.
function mod.feed_flasks(name, amount, tier, force)
    local value = storage.quality_value[force][tier]
    storage.quality_value[force][tier] = mod.dry_feed_flasks(value, name, amount, storage.difficulty_vote_value)
end

function mod.init()
    storage.quality_enabled = storage.comfy_panel_config.quality_scheduled
    storage.quality_feed_selected = {}
    storage.quality_value = {
        ['north_biters'] = {},
        ['south_biters'] = {},
    }

    for i = 1, #mod.TIERS do
        storage.quality_value['north_biters'][i] = 0.0
        storage.quality_value['south_biters'][i] = 0.0
    end

    -- 100% chance to get common biters
    storage.quality_value['north_biters'][1] = 999999
    storage.quality_value['south_biters'][1] = 999999
end

function mod.set_technologies(f)
    if mod.enabled() then
        game.forces[f].technologies['quality-module'].enabled = true
        game.forces[f].technologies['quality-module-2'].enabled = true
        game.forces[f].technologies['quality-module-3'].enabled = true
        game.forces[f].technologies['recycling'].enabled = true
        game.forces[f].technologies['epic-quality'].enabled = true
        game.forces[f].technologies['legendary-quality'].enabled = true
    elseif mod.installed() then
        game.forces[f].technologies['quality-module'].enabled = false
        game.forces[f].technologies['quality-module-2'].enabled = false
        game.forces[f].technologies['quality-module-3'].enabled = false
        game.forces[f].technologies['recycling'].enabled = false
        game.forces[f].technologies['epic-quality'].enabled = false
        game.forces[f].technologies['legendary-quality'].enabled = false
    end
end

function mod.installed()
    return script.feature_flags.quality
end

function mod.scheduled()
    return storage.comfy_panel_config.quality_scheduled
end

function mod.enabled()
    return storage.quality_enabled
end

return mod
