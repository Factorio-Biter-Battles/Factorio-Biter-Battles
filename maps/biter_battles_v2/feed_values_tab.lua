-- feed values tab --

local Tables = require('maps.biter_battles_v2.tables')
local ItemCosts = require('maps.biter_battles_v2.item_costs')
local food_values = Tables.food_values
local food_long_and_short = Tables.food_long_and_short
local Tabs = require('comfy_panel.main')

local function get_science_text(food_name, food_short_name)
    return table.concat({
        '[img=item/',
        food_name,
        '][color=',
        food_values[food_name].color,
        ']',
        food_short_name,
        '[/color]',
    })
end

local debug = false
local raw_costs = ItemCosts.raw_costs

local raw_cost_display_order = {
    'iron-ore',
    'copper-ore',
    'stone',
    'coal',
    'uranium-ore',
    'crude-oil',
    -- We intentionally exclude "water" because it is very inaccurate due
    -- to not really properly estimating oil cracking
}

---@param player LuaPlayer
---@param element LuaGuiElement
---@param food_product_info table<string, ProductInfo>
local function add_feed_values(player, element, food_product_info)
    element.add({
        type = 'label',
        caption = 'The table below is meant to give some information about the relative benefits of each different science to throw.  The resource columns assume things about where productivity modules are used, and about how difficult oil is compared to ore, which will not always be correct.  Use online factorio calculators for more flexibility/accuracy.',
    }).style.single_line =
        false
    local science_scrollpanel = element.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
    })
    science_scrollpanel.style.maximal_height = 530

    local t_summary = science_scrollpanel.add({
        type = 'table',
        name = 'feed_values_summary_header_table',
        column_count = 4,
        draw_horizontal_lines = false,
    })
    t_summary.style.top_cell_padding = 2
    t_summary.style.bottom_cell_padding = 2
    local headersSummary = {
        { 100, '', nil },
        {
            100,
            'Mutagen [img=info]',
            'A normalized value for how much mutagen is produced by sending 1 of this item. Higher values will generate more threat and more evo% increase',
        },
        {
            100,
            'Resources [img=info]',
            'The approximate raw ore cost of 1 of this item, valuing raw ore as 1, crude-oil/petro/light-oil/heavy-oil as 0.2, and water/steam as 0. This assumes 4xProd3 in the rocket silo, and 2xProd1 used in processing units, rocket control units, purple science, yellow science. This also assumes coal-powered steel furnaces are used',
        },
        {
            150,
            'Resource Efficiency [img=info]',
            'A normalized value for mutagen/resources. Higher values are more resource efficient to send',
        },
    }
    for _, column_info in ipairs(headersSummary) do
        local label = t_summary.add({ type = 'label', caption = column_info[2], tooltip = column_info[3] })
        label.style.minimal_width = column_info[1]
        label.style.horizontal_align = 'right'
    end

    local normalized_mutagen_value = nil
    local normalized_resource_value = nil
    for i = 1, #food_long_and_short do
        local mutagen_val = food_values[food_long_and_short[i].long_name].value
        local info = food_product_info[food_long_and_short[i].long_name]
        local resources = 0
        local resources_tooltip = ''
        local resource_efficiency_tooltip =
            'Resource requirements for 1000 space science every 40 minutes equivalent mutagen production.'
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
        local scale = 1000 / (40 * 60) * Tables.food_values['space-science-pack'].value / mutagen_val
        resource_efficiency_tooltip = resource_efficiency_tooltip
            .. string.format(
                '\n[img=item/%s] %.2f/s       %.0f/min',
                food_long_and_short[i].long_name,
                scale,
                scale * 60
            )
        local normalized_info = ItemCosts.scale_product_info(info, scale)
        for _, k in ipairs(raw_cost_display_order) do
            if info.raw_ingredients[k] then
                if resources_tooltip ~= '' then
                    resources_tooltip = resources_tooltip .. '\n'
                end
                resources_tooltip = resources_tooltip
                    .. string.format('%.0f  %s', info.raw_ingredients[k], raw_costs[k].icon)
                resource_efficiency_tooltip = resource_efficiency_tooltip
                    .. string.format(
                        '\n%s %.0f/s       %.0f/min',
                        raw_costs[k].icon,
                        normalized_info.raw_ingredients[k],
                        normalized_info.raw_ingredients[k] * 60
                    )
            end
        end
        resource_efficiency_tooltip = resource_efficiency_tooltip
            .. string.format('\nAverage active miners/smelters/asm/etc: %.0f', normalized_info.total_crafting_time)
        t_summary.add({
            type = 'label',
            caption = get_science_text(food_long_and_short[i].long_name, food_long_and_short[i].short_name),
        })
        local label =
            t_summary.add({ type = 'label', caption = string.format('%.1fx', mutagen_val / normalized_mutagen_value) })
        label.style.minimal_width = headersSummary[2][1]
        label.style.horizontal_align = 'right'
        local label = t_summary.add({
            type = 'label',
            caption = string.format('%.0f [img=info]', resources / 10),
            tooltip = resources_tooltip,
        })
        label.style.minimal_width = headersSummary[3][1]
        label.style.horizontal_align = 'right'
        local label = t_summary.add({
            type = 'label',
            caption = string.format(
                '%.2fx [img=info]',
                (mutagen_val / normalized_mutagen_value) / (resources / normalized_resource_value)
            ),
            tooltip = resource_efficiency_tooltip,
        })
        label.style.minimal_width = headersSummary[4][1]
        label.style.horizontal_align = 'right'
    end
end

-- TODO: Fix stack overflow in FeedValues
local function build_config_gui(player, frame)
    -- local frame_feed_values = Tabs.comfy_panel_get_active_frame(player)
    -- if not frame_feed_values then
    --     return
    -- end
    -- frame_feed_values.clear()

    -- local food_product_info = {}
    -- for food, _ in pairs(Tables.food_names) do
    --     food_product_info[food] = ItemCosts.get_info(food)
    -- end

    -- add_feed_values(player, frame_feed_values, food_product_info)
end

comfy_panel_tabs['FeedValues'] = { gui = build_config_gui, admin = false }
