-- feed values tab --

local Tables = require('maps.biter_battles_v2.tables')
local food_values = Tables.food_values
local food_long_and_short = Tables.food_long_and_short
local Tabs = require('comfy_panel.main')

local debug = false

local ItemCosts = {}

ItemCosts.raw_costs = {
    ['iron-ore'] = { cost = 10, crafting_time = 2, icon = '[item=iron-ore]' },
    ['copper-ore'] = { cost = 10, crafting_time = 2, icon = '[item=copper-ore]' },
    ['stone'] = { cost = 10, crafting_time = 2, icon = '[item=stone]' },
    ['coal'] = { cost = 10, crafting_time = 2, icon = '[item=coal]' },

    -- I am making uranium cost more, both because of the sulfuric acid, and
    -- because the mining time is longer and the patches are rare.
    ['uranium-ore'] = { cost = 20, crafting_time = 4, icon = '[item=uranium-ore]' },
    -- Crafting time here is difficult. I am assuming a pumpjack on a 80%
    -- yield oil spot.
    -- The "cost" is even trickier. How to value one oil vs one ore? Most
    -- pumpjacks will give ~8 oil/sec, vs a mining drill giving 0.5 ore/sec.
    -- However, one oil patch can generally support at most 10-20 pumpjacks,
    -- vs an ore patch supporting 60-100 mining drills. Also, setting up the
    -- pumpjacks is harder than mining drills, and the pumpjacks are more
    -- expensive than miners too.
    --
    -- So, all considered, I am treating a 1500% oil patch (requires ~20
    -- pumpjacks, 8 refineries + 9 chem plants doing cracking) as cost
    -- equivalent to 2 lanes of ore (30 miners, 48 steel furnaces).
    -- So that is 150 oil/sec == 30 ore/sec.
    ['crude-oil'] = { cost = 2, crafting_time = 0.1 / 0.8, icon = '[fluid=crude-oil]' },
    ['water'] = { cost = 0, crafting_time = 1 / 1200, icon = '[fluid=water]' },
}

local raw_costs = ItemCosts.raw_costs

local recipe_productivity = {
    ['rocket-part'] = 1.4,
    ['processing-unit'] = 1.08,
    ['rocket-part'] = 1.08,
    ['production-science-pack'] = 1.08,
    ['utility-science-pack'] = 1.08,
}

---@class ProductInfo
---@field raw_ingredients table<string, number>
---@field intermediates_union table<string, boolean>
---@field total_crafting_time number

---@return ProductInfo
local function empty_product_info()
    return { raw_ingredients = {}, intermediates_union = {}, total_crafting_time = 0 }
end

---@param a ProductInfo
---@param b ProductInfo
---@return ProductInfo
local function add_product_infos(a, b)
    local result = empty_product_info()
    for k, v in pairs(a.raw_ingredients) do
        result.raw_ingredients[k] = v
    end
    for k, v in pairs(b.raw_ingredients) do
        result.raw_ingredients[k] = (result.raw_ingredients[k] or 0) + v
    end
    for k, _ in pairs(a.intermediates_union) do
        result.intermediates_union[k] = true
    end
    for k, _ in pairs(b.intermediates_union) do
        result.intermediates_union[k] = true
    end
    result.total_crafting_time = a.total_crafting_time + b.total_crafting_time
    return result
end

---@param a ProductInfo
---@param scale number
---@return ProductInfo
function ItemCosts.scale_product_info(a, scale)
    local result = empty_product_info()
    for k, v in pairs(a.raw_ingredients) do
        result.raw_ingredients[k] = v * scale
    end
    for k, _ in pairs(a.intermediates_union) do
        result.intermediates_union[k] = true
    end
    result.total_crafting_time = a.total_crafting_time * scale
    return result
end

local scale_product_info = ItemCosts.scale_product_info

---@return table<string, ProductInfo>
local function initial_product_infos()
    local crude_craft_time = raw_costs['crude-oil'].crafting_time
    local result = {
        -- This is a bit of a hack, but for oil processing recipes, I sortof
        -- assume that advanced oil processing is used, and that all of the
        -- other outputs are useful, in order to come up with these costs.
        -- Technically, the costs for each one depend on how much cracking is
        -- needed/etc, but this is a reasonable approximation.
        -- The total_crafting_time field is even more of a joke.
        ['light-oil'] = {
            raw_ingredients = { ['crude-oil'] = 1, ['water'] = 0.5 },
            intermediates_union = {},
            total_crafting_time = 5 / 100 + crude_craft_time,
        },
        ['heavy-oil'] = {
            raw_ingredients = { ['crude-oil'] = 1, ['water'] = 0.5 },
            intermediates_union = {},
            total_crafting_time = 5 / 100 + crude_craft_time,
        },
        ['petroleum-gas'] = {
            raw_ingredients = { ['crude-oil'] = 1, ['water'] = 0.5 },
            intermediates_union = {},
            total_crafting_time = 5 / 100 + crude_craft_time,
        },
        ['steam'] = {
            raw_ingredients = { ['water'] = 1 },
            intermediates_union = {},
            total_crafting_time = 1 / 60 + raw_costs['water'].crafting_time,
        },

        -- This is assuming that light oil cracking can be used and that there
        -- is a use for the petro.
        ['solid-fuel'] = {
            raw_ingredients = { ['crude-oil'] = 10 },
            intermediates_union = {},
            total_crafting_time = 2 + 10 * crude_craft_time,
        },

        ['uranium-235'] = {
            raw_ingredients = { ['uranium-ore'] = 30 },
            intermediates_union = {},
            total_crafting_time = 60 + 30 * raw_costs['uranium-ore'].crafting_time,
        },
        ['uranium-238'] = {
            raw_ingredients = { ['uranium-ore'] = 10 },
            intermediates_union = {},
            total_crafting_time = 12 + 10 * raw_costs['uranium-ore'].crafting_time,
        },
    }
    for raw_thing, info in pairs(raw_costs) do
        result[raw_thing] = {
            raw_ingredients = { [raw_thing] = 1 },
            intermediates_union = {},
            total_crafting_time = info.crafting_time,
        }
    end
    return result
end

local get_product_info, get_product_info_uncached

---@param product string
---@param recipes table<string, table>
---@param cache table<string, ProductInfo>
---@return ProductInfo
function get_product_info(product, recipes, cache)
    if cache[product] then
        return cache[product]
    end
    cache[product] = get_product_info_uncached(product, recipes, cache)
    return cache[product]
end

---@param product string
---@param recipes table<string, table>
---@param cache table<string, ProductInfo>
---@return ProductInfo
function get_product_info_uncached(product, recipes, cache)
    local raw_cost = raw_costs[product]
    if raw_cost ~= nil then
        return raw_cost
    end
    local recipe = recipes[product]
    if not recipe then
        if product ~= 'wood' and product ~= 'raw-fish' then
            game.print('No simple recipe for ' .. product .. ' assuming zero cost')
            log('No simple recipe for ' .. product .. ' assuming zero cost')
        end
        return empty_product_info()
    end
    local info = empty_product_info()
    for _, ingredient in pairs(recipe.ingredients) do
        info = add_product_infos(
            info,
            scale_product_info(get_product_info(ingredient.name, recipes, cache), ingredient.amount)
        )
        if not raw_costs[ingredient.name] then
            info.intermediates_union[ingredient.name] = true
        end
    end
    local productivity = recipe_productivity[product]
    local crafting_speed = 1
    local category = recipe.category
    if
        category == 'crafting'
        or category == 'basic-crafting'
        or category == 'crafting-with-fluid'
        or category == 'advanced-crafting'
    then
        -- Assume Asm2
        crafting_speed = 0.75
    elseif category == 'smelting' then
        -- Assume steel furnaces
        crafting_speed = 2
        -- Assuming using coal to power the furnaces
        info.raw_ingredients['coal'] = (info.raw_ingredients['coal'] or 0) + 0.036
    end
    if productivity then
        -- Assume 2x prod1 is slowing it down
        crafting_speed = crafting_speed * 0.9
        info = scale_product_info(info, 1 / productivity)
    end
    info.total_crafting_time = info.total_crafting_time + recipe.energy / crafting_speed
    if recipe.products[1].amount ~= 1 then
        info = scale_product_info(info, 1 / recipe.products[1].amount)
    end
    if debug then
        log('Cost of ' .. product .. ' is ' .. serpent.block(info))
    end
    return info
end

---@return table<string, ProductInfo>
local function find_all_costs()
    local force = game.forces['spectator']
    local recipes = force.recipes
    local simple_recipes = {}
    local all_items = {}
    for _, recipe in pairs(recipes) do
        local products = recipe.products
        if #products == 1 and (products[1].name == recipe.name or not simple_recipes[products[1].name]) then
            simple_recipes[products[1].name] = recipe
        end
        for _, product in pairs(products) do
            all_items[product.name] = true
        end
    end
    simple_recipes['space-science-pack'] = {
        ingredients = { { name = 'rocket-part', amount = 100 }, { name = 'satellite', amount = 1 } },
        products = { { name = 'space-science-pack', amount = 1000 } },
        energy = 14.833 + 19.367 + 6.133, -- Time to launch rocket
    }
    all_items['space-science-pack'] = true
    simple_recipes['rocket-part'] = {
        ingredients = {
            { name = 'low-density-structure', amount = 10 },
            { name = 'rocket-fuel', amount = 10 },
            { name = 'rocket-part', amount = 10 },
        },
        products = { { name = 'rocket-part', amount = 1 } },
        energy = 3, -- Time to craft one rocket part
    }
    local result = {}
    local cache = initial_product_infos()
    for item, _ in pairs(all_items) do
        result[item] = get_product_info(item, simple_recipes, cache)
    end
    for item, raw_cost in pairs(raw_costs) do
        result[item] =
            { raw_ingredients = { [item] = 1 }, intermediates_union = {}, total_crafting_time = raw_cost.crafting_time }
    end
    return result
end

---@param item_name string
---@return ProductInfo
function ItemCosts.get_info(item_name)
    local item_costs = storage.bb_item_costs
    if not item_costs then
        item_costs = find_all_costs()
        storage.bb_item_costs = item_costs
    end

    return item_costs[item_name]
end

---@param item_name string
---@return number
function ItemCosts.get_cost(item_name)
    local cost = 0
    local info = ItemCosts.get_info(item_name)
    if info then
        for k, v in pairs(info.raw_ingredients) do
            cost = cost + v * raw_costs[k].cost
        end
    end
    return cost
end

return ItemCosts
