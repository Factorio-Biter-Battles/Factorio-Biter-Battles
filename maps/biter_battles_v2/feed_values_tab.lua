-- feed values tab --

local Tables = require "maps.biter_battles_v2.tables"
local food_values = Tables.food_values
local food_long_and_short = Tables.food_long_and_short

local function get_science_text(food_name, food_short_name)
    return table.concat({"[img=item/", food_name, "][color=",food_values[food_name].color, "]", food_short_name, "[/color]"})
end

local debug = false

local raw_costs = {
    ["iron-ore"] = {cost = 10, crafting_time = 2, icon = "[item=iron-ore]"},
    ["copper-ore"] = {cost = 10, crafting_time = 2, icon = "[item=copper-ore]"},
    ["stone"] = {cost = 10, crafting_time = 2, icon = "[item=stone]"},
    ["coal"] = {cost = 10, crafting_time = 2, icon = "[item=coal]"},

    -- I am making uranium cost more, both because of the sulfuric acid, and
    -- because the mining time is longer and the patches are rare.
    ["uranium-ore"] = {cost = 20, crafting_time = 4, icon = "[item=uranium-ore]"},
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
    ["crude-oil"] = {cost = 2, crafting_time = 0.1/0.8, icon = "[fluid=crude-oil]"},
    ["water"] = {cost = 0, crafting_time = 1/1200, icon = "[fluid=water]"},
}

local raw_cost_display_order = {
    "iron-ore",
    "copper-ore",
    "stone",
    "coal",
    "uranium-ore",
    "crude-oil",
    -- We intentionally exclude "water" because it is very inaccurate due
    -- to not really properly estimating oil cracking
}

local recipe_productivity = {
    ["rocket-part"] = 1.4,
    ["processing-unit"] = 1.08,
    ["rocket-control-unit"] = 1.08,
    ["production-science-pack"] = 1.08,
    ["utility-science-pack"] = 1.08,
}

---@class ProductInfo
---@field raw_ingredients table<string, number>
---@field intermediates_union table<string, boolean>
---@field total_crafting_time number

---@return ProductInfo
local function empty_product_info()
    return {raw_ingredients = {}, intermediates_union = {}, total_crafting_time = 0}
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
local function scale_product_info(a, scale)
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

---@return table<string, ProductInfo>
local function initial_product_infos()
    local crude_craft_time = raw_costs["crude-oil"].crafting_time
    local result = {
        -- This is a bit of a hack, but for oil processing recipes, I sortof
        -- assume that advanced oil processing is used, and that all of the
        -- other outputs are useful, in order to come up with these costs.
        -- Technically, the costs for each one depend on how much cracking is
        -- needed/etc, but this is a reasonable approximation.
        -- The total_crafting_time field is even more of a joke.
        ["light-oil"] = {raw_ingredients = {["crude-oil"] = 1, ["water"] = 0.5}, intermediates_union = {}, total_crafting_time = 5/100 + crude_craft_time},
        ["heavy-oil"] = {raw_ingredients = {["crude-oil"] = 1, ["water"] = 0.5}, intermediates_union = {}, total_crafting_time = 5/100 + crude_craft_time},
        ["petroleum-gas"] = {raw_ingredients = {["crude-oil"] = 1, ["water"] = 0.5}, intermediates_union = {}, total_crafting_time = 5/100 + crude_craft_time},
        ["steam"] = {raw_ingredients = {["water"] = 1}, intermediates_union = {}, total_crafting_time = 1/60 + raw_costs["water"].crafting_time},

        -- This is assuming that light oil cracking can be used and that there
        -- is a use for the petro.
        ["solid-fuel"] = {raw_ingredients = {["crude-oil"] = 10}, intermediates_union = {}, total_crafting_time = 2 + 10 * crude_craft_time},

        ["uranium-235"] = {raw_ingredients = {["uranium-ore"] = 30}, intermediates_union = {}, total_crafting_time = 60 + 30 * raw_costs["uranium-ore"].crafting_time},
        ["uranium-238"] = {raw_ingredients = {["uranium-ore"] = 10}, intermediates_union = {}, total_crafting_time = 12 + 10 * raw_costs["uranium-ore"].crafting_time},
    }
    for raw_thing, info in pairs(raw_costs) do
        result[raw_thing] = {raw_ingredients = {[raw_thing] = 1}, intermediates_union = {}, total_crafting_time = info.crafting_time}
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
        game.print("No simple recipe for " .. product .. " assuming zero cost")
        log("No simple recipe for " .. product .. " assuming zero cost")
        return empty_product_info()
    end
    local info = empty_product_info()
    for _, ingredient in pairs(recipe.ingredients) do
        info = add_product_infos(info, scale_product_info(get_product_info(ingredient.name, recipes, cache), ingredient.amount))
        if not raw_costs[ingredient.name] then
            info.intermediates_union[ingredient.name] = true
        end
    end
    local productivity = recipe_productivity[product]
    local crafting_speed = 1
    local category = recipe.category
    if category == "crafting" or category == "basic-crafting" or category == "crafting-with-fluid" or category == "advanced-crafting" then
        -- Assume Asm2
        crafting_speed = 0.75
    elseif category == "smelting" then
        -- Assume steel furnaces
        crafting_speed = 2
        -- Assuming using coal to power the furnaces
        info.raw_ingredients["coal"] = (info.raw_ingredients["coal"] or 0) + 0.036
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
        log("Cost of " .. product .. " is " .. serpent.block(info))
    end
    return info
end

---@param food_names table<string, boolean>
---@return table<string, ProductInfo>
local function find_costs(food_names)
    local force = game.forces["spectator"]
    local recipes = force.recipes
    local simple_recipes = {}
    for _, recipe in pairs(recipes) do
        local products = recipe.products
        if #products == 1 and products[1].name == recipe.name then
            simple_recipes[recipe.name] = recipe
        end
    end
    simple_recipes["space-science-pack"] = {
        ingredients = {{name = "rocket-part", amount = 100}, {name = "satellite", amount = 1}},
        products = {{name = "space-science-pack", amount = 1000}},
        energy = 14.833 + 19.367 + 6.133 -- Time to launch rocket
    }
    simple_recipes["rocket-part"] = {
        ingredients = {{name = "low-density-structure", amount = 10}, {name = "rocket-fuel", amount = 10}, {name = "rocket-control-unit", amount = 10}},
        products = {{name = "rocket-part", amount = 1}},
        energy = 3  -- Time to craft one rocket part
    }
    local result = {}
    local cache = initial_product_infos()
    for food_name, _ in pairs(food_names) do
        result[food_name] = get_product_info(food_name, simple_recipes, cache)
    end
    return result
end

---@param player LuaPlayer
---@param element LuaGuiElement
---@param food_product_info table<string, ProductInfo>
local function add_feed_values(player, element, food_product_info)
    element.add{type = "label", caption = "The table below is meant to give some information about the relative benefits of each different science to throw.  The resource columns assume things about where productivity modules are used, and about how difficult oil is compared to ore, which will not always be correct.  Use online factorio calculators for more flexibility/accuracy."}.style.single_line = false
    local science_scrollpanel = element.add { type = "scroll-pane", name = "scroll_pane", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"}
    science_scrollpanel.style.maximal_height = 530

    local t_summary = science_scrollpanel.add { type = "table", name = "feed_values_summary_header_table", column_count = 4, draw_horizontal_lines = false }
    t_summary.style.top_cell_padding = 2
    t_summary.style.bottom_cell_padding = 2
    local headersSummary = {
        {100, "", nil},
        {100, "Mutagen [img=info]", "A normalized value for how much mutagen is produced by sending 1 of this item. Higher values will generate more threat and more evo% increase"},
        {100, "Resources [img=info]", "The approximate raw ore cost of 1 of this item, valuing raw ore as 1, crude-oil/petro/light-oil/heavy-oil as 0.2, and water/steam as 0. This assumes 4xProd3 in the rocket silo, and 2xProd1 used in processing units, rocket control units, purple science, yellow science. This also assumes coal-powered steel furnaces are used"},
        {150, "Resource Efficiency [img=info]", "A normalized value for mutagen/resources. Higher values are more resource efficient to send"}
    }
    for _, column_info in ipairs(headersSummary) do
        local label = t_summary.add { type = "label", caption = column_info[2], tooltip = column_info[3] }
        label.style.minimal_width = column_info[1]
        label.style.horizontal_align = 'right'
    end

    local normalized_mutagen_value = nil
    local normalized_resource_value = nil
    for i = 1, #food_long_and_short do
        local mutagen_val = food_values[food_long_and_short[i].long_name].value
        local info = food_product_info[food_long_and_short[i].long_name]
        local resources = 0
        local resources_tooltip = ""
        local resource_efficiency_tooltip = "Resource requirements for 1000 space science every 40 minutes equivalent mutagen production."
        local num_intermediates = 0
        for k, v in pairs(info.raw_ingredients) do
            resources = resources + v * raw_costs[k].cost
            num_intermediates = num_intermediates + 1
        end
        for k, _ in pairs(info.intermediates_union) do
            num_intermediates = num_intermediates + 1
        end
        if not normalized_mutagen_value then
            normalized_mutagen_value = mutagen_val
            normalized_resource_value = resources
        end
        local scale = 1000/(40*60) * Tables.food_values["space-science-pack"].value / mutagen_val
        resource_efficiency_tooltip = resource_efficiency_tooltip .. string.format("\n[img=item/%s] %.2f/s       %.0f/min", food_long_and_short[i].long_name, scale, scale*60)
        local normalized_info = scale_product_info(info, scale)
        for _, k in ipairs(raw_cost_display_order) do
            if info.raw_ingredients[k] then
                if resources_tooltip ~= "" then
                    resources_tooltip = resources_tooltip .. "\n"
                end
                resources_tooltip = resources_tooltip .. string.format("%.0f  %s", info.raw_ingredients[k], raw_costs[k].icon)
                resource_efficiency_tooltip = resource_efficiency_tooltip .. string.format("\n%s %.0f/s       %.0f/min", raw_costs[k].icon, normalized_info.raw_ingredients[k], normalized_info.raw_ingredients[k]*60)
            end
        end
        resource_efficiency_tooltip = resource_efficiency_tooltip .. string.format("\nAverage active miners/smelters/asm/etc: %.0f", normalized_info.total_crafting_time)
        t_summary.add { type = "label", caption = get_science_text(food_long_and_short[i].long_name, food_long_and_short[i].short_name) }
        local label = t_summary.add { type = "label", caption = string.format("%.1fx", mutagen_val / normalized_mutagen_value) }
        label.style.minimal_width = headersSummary[2][1]
        label.style.horizontal_align = 'right'
        local label = t_summary.add { type = "label", caption = string.format("%.0f [img=info]", resources / 10), tooltip = resources_tooltip }
        label.style.minimal_width = headersSummary[3][1]
        label.style.horizontal_align = 'right'
        local label = t_summary.add { type = "label", caption = string.format("%.2fx [img=info]", (mutagen_val / normalized_mutagen_value) / (resources / normalized_resource_value)), tooltip = resource_efficiency_tooltip }
        label.style.minimal_width = headersSummary[4][1]
        label.style.horizontal_align = 'right'
    end
end

local function comfy_panel_get_active_frame(player)
    if not player.gui.left.comfy_panel then return false end
    if not player.gui.left.comfy_panel.tabbed_pane.selected_tab_index then return player.gui.left.comfy_panel.tabbed_pane.tabs[1].content end
    return player.gui.left.comfy_panel.tabbed_pane.tabs[player.gui.left.comfy_panel.tabbed_pane.selected_tab_index].content
end

local function build_config_gui(player, frame)
    local frame_feed_values = comfy_panel_get_active_frame(player)
    if not frame_feed_values then
        return
    end
    frame_feed_values.clear()

    local food_product_info = global.bb_food_product_info
    if not food_product_info then
        food_product_info = find_costs(Tables.food_names)
        global.bb_food_product_info = food_product_info
    end

    add_feed_values(player, frame_feed_values, food_product_info)
end

comfy_panel_tabs["FeedValues"] = {gui = build_config_gui, admin = false}
