local Tabs = require 'comfy_panel.main'
local changes = require 'changes'

local function add_changelog(player, element)
    local changelog_scrollpanel = element.add { type = "scroll-pane", name = "scroll_pane", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"}
    changelog_scrollpanel.style.vertically_squashable = true
    changelog_scrollpanel.style.padding = 2

    local t = changelog_scrollpanel.add { type = "table", name = "changelog_header_table", column_count = 3 }
    local column_widths = {tonumber(100), tonumber(525), tonumber(145)}
    local headers = {
        [1] = "Date",
        [2] = "Change",
        [3] = "Author",
    }
    for _, w in ipairs(column_widths) do
        local label = t.add { type = "label", caption = headers[_] }
        label.style.minimal_width = w
        label.style.maximal_width = w
        label.style.font = "default-bold"
        label.style.font_color = { r=0.98, g=0.66, b=0.22 }
    end

    local changelog_panel_table = changelog_scrollpanel.add { type = "table", column_count = 3 }
    for _, change in ipairs(changes) do
        local label = changelog_panel_table.add { type = "label", caption = change.date }
        label.style.minimal_width = column_widths[1]
        label.style.maximal_width = column_widths[1]
        label = changelog_panel_table.add { type = "label", caption = change.comment }
        label.style.minimal_width = column_widths[2]
        label.style.maximal_width = column_widths[2]
        label.style.single_line = false
        label = changelog_panel_table.add { type = "label", caption = change.author }
        label.style.minimal_width = column_widths[3]
        label.style.maximal_width = column_widths[3]
    end
end

local build_config_gui = (function (player, frame)
    local frame_changelog = Tabs.comfy_panel_get_active_frame(player)
    if not frame_changelog then
        return
    end
    frame_changelog.clear()
    add_changelog(player, frame_changelog)
end)

comfy_panel_tabs["Changelog"] = {gui = build_config_gui, admin = false}
