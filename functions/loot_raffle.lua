--[[
roll(budget, max_slots, blacklist) returns a table with item-stacks
budget		-	the total value of the item stacks combined
max_slots	-	the maximum amount of item stacks to return
blacklist		-	optional list of item names that can not be rolled. example: {["substation"] = true, ["roboport"] = true,}
]]
local Public = {}

local table_shuffle_table = table.shuffle_table
local table_insert = table.insert
local table_remove = table.remove
local math_random = math.random
local math_floor = math.floor

local item_worths = {
    ['accumulator'] = 64,
    ['active-provider-chest'] = 256,
    ['advanced-circuit'] = 16,
    ['arithmetic-combinator'] = 16,
    ['artillery-shell'] = 128,
    ['artillery-targeting-remote'] = 1024,
    ['artillery-turret'] = 1024,
    ['artillery-wagon'] = 16384,
    ['assembling-machine-1'] = 32,
    ['assembling-machine-2'] = 128,
    ['assembling-machine-3'] = 512,
    ['atomic-bomb'] = 8192,
    ['automation-science-pack'] = 4,
    ['barrel'] = 2,
    ['battery'] = 16,
    ['battery-equipment'] = 96,
    ['battery-mk2-equipment'] = 2048,
    ['beacon'] = 512,
    ['belt-immunity-equipment'] = 128,
    ['big-electric-pole'] = 64,
    ['boiler'] = 8,
    ['buffer-chest'] = 512,
    ['bulk-inserter'] = 128,
    ['burner-inserter'] = 2,
    ['burner-mining-drill'] = 8,
    ['cannon-shell'] = 8,
    ['car'] = 128,
    ['cargo-wagon'] = 256,
    ['centrifuge'] = 2048,
    ['chemical-plant'] = 128,
    ['chemical-science-pack'] = 128,
    ['cliff-explosives'] = 32,
    ['cluster-grenade'] = 64,
    ['combat-shotgun'] = 256,
    ['concrete'] = 1,
    ['constant-combinator'] = 8,
    ['construction-robot'] = 256,
    ['copper-cable'] = 1,
    ['copper-plate'] = 1,
    ['crude-oil-barrel'] = 8,
    ['decider-combinator'] = 16,
    ['defender-capsule'] = 48,
    ['depleted-uranium-fuel-cell'] = 8,
    ['destroyer-capsule'] = 1024,
    ['discharge-defense-equipment'] = 2048,
    ['discharge-defense-remote'] = 32,
    ['distractor-capsule'] = 256,
    ['efficiency-module'] = 128,
    ['efficiency-module-2'] = 512,
    ['efficiency-module-3'] = 2048,
    ['electric-engine-unit'] = 64,
    ['electric-furnace'] = 256,
    ['electric-mining-drill'] = 32,
    ['electronic-circuit'] = 4,
    ['energy-shield-equipment'] = 128,
    ['energy-shield-mk2-equipment'] = 2048,
    ['engine-unit'] = 8,
    ['exoskeleton-equipment'] = 1500,
    ['explosive-cannon-shell'] = 16,
    ['explosive-rocket'] = 8,
    ['explosive-uranium-cannon-shell'] = 64,
    ['explosives'] = 3,
    ['express-loader'] = 1024,
    ['express-splitter'] = 256,
    ['express-transport-belt'] = 64,
    ['express-underground-belt'] = 256,
    ['fast-inserter'] = 16,
    ['fast-loader'] = 256,
    ['fast-splitter'] = 64,
    ['fast-transport-belt'] = 16,
    ['fast-underground-belt'] = 64,
    ['firearm-magazine'] = 4,
    ['fission-reactor-equipment'] = 15000,
    ['flamethrower'] = 512,
    ['flamethrower-ammo'] = 32,
    ['flamethrower-turret'] = 2048,
    ['fluid-wagon'] = 256,
    ['flying-robot-frame'] = 128,
    ['gate'] = 16,
    ['grenade'] = 16,
    ['gun-turret'] = 64,
    ['hazard-concrete'] = 1,
    ['heat-exchanger'] = 256,
    ['heat-pipe'] = 128,
    ['heavy-armor'] = 250,
    ['heavy-oil-barrel'] = 16,
    ['inserter'] = 4,
    ['iron-chest'] = 8,
    ['iron-gear-wheel'] = 2,
    ['iron-plate'] = 1,
    ['iron-stick'] = 1,
    ['lab'] = 64,
    ['land-mine'] = 2,
    ['landfill'] = 20,
    ['laser-turret'] = 1024,
    ['light-armor'] = 50,
    ['light-oil-barrel'] = 16,
    ['loader'] = 128,
    ['locomotive'] = 512,
    ['logistic-robot'] = 256,
    ['logistic-science-pack'] = 16,
    ['long-handed-inserter'] = 8,
    ['low-density-structure'] = 64,
    ['lubricant-barrel'] = 16,
    ['medium-electric-pole'] = 32,
    ['military-science-pack'] = 64,
    ['modular-armor'] = 512,
    ['night-vision-equipment'] = 256,
    ['nuclear-fuel'] = 1024,
    ['nuclear-reactor'] = 8192,
    ['offshore-pump'] = 16,
    ['oil-refinery'] = 256,
    ['passive-provider-chest'] = 256,
    ['personal-laser-defense-equipment'] = 1500,
    ['personal-roboport-equipment'] = 512,
    ['personal-roboport-mk2-equipment'] = 4096,
    ['petroleum-gas-barrel'] = 16,
    ['piercing-rounds-magazine'] = 8,
    ['piercing-shotgun-shell'] = 16,
    ['pipe'] = 1,
    ['pipe-to-ground'] = 8,
    ['pistol'] = 10,
    ['plastic-bar'] = 8,
    ['poison-capsule'] = 32,
    ['power-armor'] = 2048,
    ['power-armor-mk2'] = 32768,
    ['power-switch'] = 16,
    ['processing-unit'] = 128,
    ['production-science-pack'] = 256,
    ['productivity-module'] = 128,
    ['productivity-module-2'] = 512,
    ['productivity-module-3'] = 2048,
    ['programmable-speaker'] = 16,
    ['pump'] = 32,
    ['pumpjack'] = 64,
    ['radar'] = 32,
    ['rail'] = 4,
    ['rail-chain-signal'] = 8,
    ['rail-signal'] = 8,
    ['refined-concrete'] = 2,
    ['refined-hazard-concrete'] = 2,
    ['repair-pack'] = 8,
    ['roboport'] = 2048,
    ['rocket'] = 6,
    ['rocket-fuel'] = 256,
    ['rocket-launcher'] = 128,
    ['rocket-part'] = 256,
    ['rocket-silo'] = 65536,
    ['satellite'] = 32768,
    ['shotgun'] = 16,
    ['shotgun-shell'] = 4,
    ['slowdown-capsule'] = 16,
    ['small-electric-pole'] = 2,
    ['small-lamp'] = 4,
    ['solar-panel'] = 64,
    ['solar-panel-equipment'] = 256,
    ['solid-fuel'] = 16,
    ['space-science-pack'] = 512,
    ['speed-module'] = 128,
    ['speed-module-2'] = 512,
    ['speed-module-3'] = 2048,
    ['splitter'] = 16,
    ['steam-engine'] = 32,
    ['steam-turbine'] = 256,
    ['steel-chest'] = 32,
    ['steel-furnace'] = 64,
    ['steel-plate'] = 8,
    ['stone-brick'] = 2,
    ['stone-furnace'] = 4,
    ['stone-wall'] = 5,
    ['storage-tank'] = 64,
    ['submachine-gun'] = 32,
    ['substation'] = 256,
    ['sulfur'] = 4,
    ['sulfuric-acid-barrel'] = 16,
    ['tank'] = 4096,
    ['train-stop'] = 64,
    ['transport-belt'] = 2,
    ['underground-belt'] = 8,
    ['uranium-235'] = 1024,
    ['uranium-238'] = 32,
    ['uranium-cannon-shell'] = 64,
    ['uranium-fuel-cell'] = 128,
    ['uranium-rounds-magazine'] = 64,
    ['utility-science-pack'] = 256,
    ['water-barrel'] = 4,
    ['wood'] = 1,
    ['wooden-chest'] = 2,
    ['requester-chest'] = 512,
    ['storage-chest'] = 256,
}

local tech_tier_list = {
    'accumulator',
    'active-provider-chest',
    'advanced-circuit',
    'arithmetic-combinator',
    'artillery-shell',
    'artillery-targeting-remote',
    'artillery-turret',
    'artillery-wagon',
    'assembling-machine-1',
    'assembling-machine-2',
    'assembling-machine-3',
    'atomic-bomb',
    'automation-science-pack',
    'barrel',
    'battery',
    'battery-equipment',
    'battery-mk2-equipment',
    'beacon',
    'belt-immunity-equipment',
    'big-electric-pole',
    'boiler',
    'buffer-chest',
    'bulk-inserter',
    'burner-inserter',
    'burner-mining-drill',
    'cannon-shell',
    'car',
    'cargo-wagon',
    'centrifuge',
    'chemical-plant',
    'chemical-science-pack',
    'cliff-explosives',
    'cluster-grenade',
    'combat-shotgun',
    'concrete',
    'constant-combinator',
    'construction-robot',
    'copper-cable',
    'copper-plate',
    'crude-oil-barrel',
    'decider-combinator',
    'defender-capsule',
    'depleted-uranium-fuel-cell',
    'destroyer-capsule',
    'discharge-defense-equipment',
    'discharge-defense-remote',
    'distractor-capsule',
    'efficiency-module',
    'efficiency-module-2',
    'efficiency-module-3',
    'electric-engine-unit',
    'electric-furnace',
    'electric-mining-drill',
    'electronic-circuit',
    'energy-shield-equipment',
    'energy-shield-mk2-equipment',
    'engine-unit',
    'exoskeleton-equipment',
    'explosive-cannon-shell',
    'explosive-rocket',
    'explosive-uranium-cannon-shell',
    'explosives',
    'express-loader',
    'express-splitter',
    'express-transport-belt',
    'express-underground-belt',
    'fast-inserter',
    'fast-loader',
    'fast-splitter',
    'fast-transport-belt',
    'fast-underground-belt',
    'firearm-magazine',
    'fission-reactor-equipment',
    'flamethrower',
    'flamethrower-ammo',
    'flamethrower-turret',
    'fluid-wagon',
    'flying-robot-frame',
    'gate',
    'grenade',
    'gun-turret',
    'hazard-concrete',
    'heat-exchanger',
    'heat-pipe',
    'heavy-armor',
    'heavy-oil-barrel',
    'inserter',
    'iron-chest',
    'iron-gear-wheel',
    'iron-plate',
    'iron-stick',
    'lab',
    'land-mine',
    'landfill',
    'laser-turret',
    'light-armor',
    'light-oil-barrel',
    'loader',
    'locomotive',
    'logistic-robot',
    'logistic-science-pack',
    'long-handed-inserter',
    'low-density-structure',
    'lubricant-barrel',
    'medium-electric-pole',
    'military-science-pack',
    'modular-armor',
    'night-vision-equipment',
    'nuclear-fuel',
    'nuclear-reactor',
    'offshore-pump',
    'oil-refinery',
    'passive-provider-chest',
    'personal-laser-defense-equipment',
    'personal-roboport-equipment',
    'personal-roboport-mk2-equipment',
    'petroleum-gas-barrel',
    'piercing-rounds-magazine',
    'piercing-shotgun-shell',
    'pipe',
    'pipe-to-ground',
    'pistol',
    'plastic-bar',
    'poison-capsule',
    'power-armor',
    'power-armor-mk2',
    'power-switch',
    'processing-unit',
    'production-science-pack',
    'productivity-module',
    'productivity-module-2',
    'productivity-module-3',
    'programmable-speaker',
    'pump',
    'pumpjack',
    'radar',
    'rail',
    'rail-chain-signal',
    'rail-signal',
    'refined-concrete',
    'refined-hazard-concrete',
    'repair-pack',
    'requester-chest',
    'roboport',
    'roboport',
    'rocket',
    'rocket-fuel',
    'rocket-launcher',
    'rocket-part',
    'rocket-silo',
    'satellite',
    'shotgun',
    'shotgun-shell',
    'slowdown-capsule',
    'small-electric-pole',
    'small-lamp',
    'solar-panel',
    'solar-panel-equipment',
    'solid-fuel',
    'space-science-pack',
    'speed-module',
    'speed-module-2',
    'speed-module-3',
    'splitter',
    'steam-engine',
    'steam-turbine',
    'steel-chest',
    'steel-furnace',
    'steel-plate',
    'stone-brick',
    'stone-furnace',
    'stone-wall',
    'storage-chest',
    'storage-tank',
    'submachine-gun',
    'substation',
    'sulfur',
    'sulfuric-acid-barrel',
    'tank',
    'train-stop',
    'transport-belt',
    'underground-belt',
    'uranium-235',
    'uranium-238',
    'uranium-cannon-shell',
    'uranium-fuel-cell',
    'uranium-rounds-magazine',
    'utility-science-pack',
    'water-barrel',
    'wooden-chest',
}

local item_names = {}
for k, v in pairs(item_worths) do
    table_insert(item_names, k)
end
local size_of_item_names = #item_names

local function get_raffle_keys()
    local raffle_keys = {}
    for i = 1, size_of_item_names, 1 do
        raffle_keys[i] = i
    end
    table_shuffle_table(raffle_keys)
    return raffle_keys
end

function Public.roll_item_stack(remaining_budget, blacklist)
    if remaining_budget <= 0 then
        return
    end
    local raffle_keys = get_raffle_keys()
    local item_name = false
    local item_worth = 0
    for _, index in pairs(raffle_keys) do
        item_name = item_names[index]
        item_worth = item_worths[item_name]
        if not blacklist[item_name] and item_worth <= remaining_budget then
            break
        end
    end

    local stack_size = prototypes.item[item_name].stack_size

    local item_count = 1

    for c = 1, math_random(1, stack_size), 1 do
        local price = c * item_worth
        if price <= remaining_budget then
            item_count = c
        else
            break
        end
    end

    return { name = item_name, count = item_count }
end

local function roll_item_stacks(remaining_budget, max_slots, blacklist)
    local item_stack_set = {}
    local item_stack_set_worth = 0

    for i = 1, max_slots, 1 do
        if remaining_budget <= 0 then
            break
        end
        local item_stack = Public.roll_item_stack(remaining_budget, blacklist)
        item_stack_set[i] = item_stack
        remaining_budget = remaining_budget - item_stack.count * item_worths[item_stack.name]
        item_stack_set_worth = item_stack_set_worth + item_stack.count * item_worths[item_stack.name]
    end

    return item_stack_set, item_stack_set_worth
end

function Public.roll(budget, max_slots, blacklist)
    if not budget then
        return
    end
    if not max_slots then
        return
    end

    local b
    if not blacklist then
        b = {}
    else
        b = blacklist
    end

    budget = math_floor(budget)
    if budget == 0 then
        return
    end

    local final_stack_set
    local final_stack_set_worth = 0

    for attempt = 1, 5, 1 do
        local item_stack_set, item_stack_set_worth = roll_item_stacks(budget, max_slots, b)
        if item_stack_set_worth > final_stack_set_worth or item_stack_set_worth == budget then
            final_stack_set = item_stack_set
            final_stack_set_worth = item_stack_set_worth
        end
    end
    --[[
	for k, item_stack in pairs(final_stack_set) do
		game.print(item_stack.count .. "x " .. item_stack.name)
	end
	game.print(final_stack_set_worth)
	]]
    return final_stack_set
end

--tier = float 0-1; 1 = everything unlocked
function Public.get_tech_blacklist(tier)
    local blacklist = {}
    local size_of_tech_tier_list = #tech_tier_list
    local min_index = math_floor(size_of_tech_tier_list * tier)
    for i = size_of_tech_tier_list, min_index, -1 do
        blacklist[tech_tier_list[i]] = true
    end
    return blacklist
end

function Public.get_item_value(item)
    local value = item_worths[item]
    return value
end

return Public
