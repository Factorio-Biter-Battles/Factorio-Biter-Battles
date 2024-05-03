local gui_style = require 'utils.utils'.gui_style
local Functions = require 'maps.biter_battles_v2.functions'

local ResearchInfo = {}

function ResearchInfo.create_research_info_button(element, player)
    local b = element.add({
        type = "sprite-button",
        sprite = "item/space-science-pack",
        name = "research_info_button",
        tooltip =
        "Science Info"
    })
    gui_style(b, { width = 18, height = 18, padding = -2 })
end

---@param force string
---@param tech_name string
function ResearchInfo.research_finished(tech_name, force)
    local force_name = force.name
    if force_name ~= "north" and force_name ~= "south" then return end
    local tech_info = global.research_info.completed[tech_name]
    if not tech_info then
        tech_info = {}
        global.research_info.completed[tech_name] = tech_info
    end
    tech_info[force_name] = Functions.get_ticks_since_game_start()
    global.research_info.current_progress[force_name][tech_name] = nil
    ResearchInfo.update_research_info_ui()
end

---@param force string
---@param tech_name string
function ResearchInfo.research_started(tech_name, force)
    local force_name = force.name
    if force_name ~= "north" and force_name ~= "south" then return end
    global.research_info.current_progress[force_name][tech_name] = true
    ResearchInfo.update_research_info_ui()
end

---@param force LuaForce
---@param tech_name string
function ResearchInfo.research_reversed(tech_name, force)
    if force.name ~= "north" and force.name ~= "south" then return end
    local tech_info = global.research_info.completed[tech_name]
    if not tech_info then return end
    tech_info[force.name] = nil
    ResearchInfo.update_research_info_ui()
end

---@param element LuaGuiElement
---@param filter_fn function
local function add_completed_research_icons(element, all_technologies, filter_fn)
    local icons_to_add = {}
    for tech_name, tech_info in pairs(global.research_info.completed) do
        if filter_fn(tech_name, tech_info) then
            local tooltip = { "", all_technologies[tech_name].localised_name }
            local time = math.huge
            if tech_info.north then
                table.insert(tooltip, "\nNorth: " .. Functions.format_ticks_as_time(tech_info.north))
                time = math.min(time, tech_info.north)
            end
            if tech_info.south then
                table.insert(tooltip, "\nSouth: " .. Functions.format_ticks_as_time(tech_info.south))
                time = math.min(time, tech_info.south)
            end
            local icon = { type = "sprite", sprite = "technology/" .. tech_name, tooltip = tooltip, elem_tooltip = { type = "technology", name = tech_name } }
            table.insert(icons_to_add, { time = time, icon = icon })
        end
    end
    table.sort(icons_to_add, function(a, b) return a.time < b.time end)
    for _, icon in ipairs(icons_to_add) do
        local tech = element.add(icon.icon)
        gui_style(tech, { width = 38, height = 38, padding = -2, stretch_image_to_widget_size = true })
    end
end

---@param element LuaGuiElement
---@param force LuaForce
local function add_research_queue_icons(element, force, all_technologies)
    local queue = force.research_queue
    if not queue or #queue == 0 then
        element.add { type = "label", caption = "empty" }
        return
    end
    local icons_to_add = {}
    for _, tech in ipairs(queue) do
        local tooltip = tech.localised_name
        local time = math.huge
        local icon = { type = "sprite", sprite = "technology/" .. tech.name, tooltip = tooltip, elem_tooltip = { type = "technology", name = tech.name } }
        table.insert(icons_to_add, { time = time, icon = icon })
    end
    element.add { type = "label", caption = "Queue: " }
    for _, icon in ipairs(icons_to_add) do
        local tech = element.add(icon.icon)
        gui_style(tech, { width = 38, height = 38, padding = -2, stretch_image_to_widget_size = true })
    end
end

---@param element LuaGuiElement
---@param force LuaForce
local function add_research_progress_icons(element, force)
    local all_technologies = force.technologies
    -- force.get_saved_technology_progress
    local progress_info = global.research_info.current_progress[force.name]
    local icons_to_add = {}
    -- For testing:
    -- progress_info["automation"] = 0.4
    local current_tech = force.current_research
    for tech_name, _ in pairs(progress_info) do
        local progress
        if current_tech and current_tech.name == tech_name then
            progress = force.research_progress
        else
            progress = force.get_saved_technology_progress(all_technologies[tech_name])
        end
        if progress and progress > 0 then
            local percentage = string.format("%.0f%% complete", progress * 100)
            local icon = { type = "sprite", sprite = "technology/" .. tech_name, tooltip = percentage, elem_tooltip = { type = "technology", name = tech_name }  }
            table.insert(icons_to_add, { icon = icon, progress = progress })
        end
    end
    -- Just alphabetical sort by technology name so that the order is stable
    table.sort(icons_to_add, function(a, b) return a.icon.sprite < b.icon.sprite end)
    for _, icon in ipairs(icons_to_add) do
        local stacker = element.add { type = "flow", direction = "vertical" }
        gui_style(stacker, {vertical_spacing = 0, width = 38})
        local tech = stacker.add(icon.icon)
        local percentage = string.format("%.0f%% complete", icon.progress * 100)
        local progress = stacker.add { type="progressbar", value = icon.progress, tooltip=percentage }
        gui_style(tech, { width = 38, height = 38, stretch_image_to_widget_size = true })
        gui_style(progress, { height = 8, horizontally_stretchable = true})
    end
end

local function update_research_info_element(element)
    local all_technologies = game.forces.spectator.technologies
    local scrollpanel = element.scroll_pane
    local frame_teams = scrollpanel.teams
    for _, force_name in ipairs({"north", "south"}) do
        local other_force_name = force_name == "north" and "south" or "north"
        local team_frame = frame_teams[force_name]
        local force = game.forces[force_name]
        team_frame.research_queue.clear()
        add_research_queue_icons(team_frame.research_queue, force, all_technologies)
        local progress = team_frame.progress
        progress.clear()
        add_research_progress_icons(progress, force)

        team_frame.completed_research.clear()
        add_completed_research_icons(team_frame.completed_research,
            all_technologies,
            function(tech_name, tech_info) return tech_info[force_name] and not tech_info[other_force_name] end)
    end

    scrollpanel.completed_research.clear()
    add_completed_research_icons(scrollpanel.completed_research,
        all_technologies,
        function(tech_name, tech_info) return tech_info.north and tech_info.south end)
end

function ResearchInfo.update_research_info_ui()
    for _, player in pairs(game.connected_players) do
        if player.gui.center["research_info_frame"] then
            update_research_info_element(player.gui.center["research_info_frame"])
        end
    end
end

function ResearchInfo.show_research_info(player)
    local all_technologies = game.forces.spectator.technologies
    if player.gui.center["research_info_frame"] then
        player.gui.center["research_info_frame"].destroy()
        return
    end
    local frame = player.gui.center.add { type = "frame", name = "research_info_frame", direction = "vertical" }
    gui_style(frame, { padding = 8 })
    local scrollpanel = frame.add { type = "scroll-pane", name = "scroll_pane", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto" }
    local label
    local horizontal_flow = scrollpanel.add { type = "flow", direction = "horizontal" }
    label = horizontal_flow.add { type = "label", caption = "Research Summary for both teams" }
    gui_style(label, { font = "heading-1" })
    local spacer_flow = horizontal_flow.add { type = "flow", direction = "horizontal" }
    gui_style(spacer_flow, { horizontally_stretchable = true, horizontal_align = "right" })
    local button = spacer_flow.add({
        type = "button",
        name = "research_info_close", -- clicking on any element works to close
        caption = "Close",
        tooltip = "Close this window."
    })
    local frame_teams = scrollpanel.add { type = "table", name = "teams", column_count = 2, vertical_centering = false }
    for _, force_name in ipairs({"north", "south"}) do
        local team_frame = frame_teams.add { type = "frame", name = force_name, direction = "vertical", caption = Functions.team_name_with_color(force_name) }
        gui_style(team_frame, { natural_width = 365, vertically_stretchable = true })

        label = team_frame.add { type = "label", caption = "Current Queue" }
        gui_style(label, { font = "heading-2" })
        team_frame.add { type = "flow", name = "research_queue", direction = "horizontal" }
        local progress = team_frame.add { type = "table", name = "progress", column_count = 15 }
        gui_style(progress, { horizontally_stretchable = false})

        label = team_frame.add { type = "label", caption = "Researched (exclusive)" }
        gui_style(label, { font = "heading-2" })
        team_frame.add { type = "table", name = "completed_research", column_count = 8 }
    end

    label = scrollpanel.add { type = "label", caption = "Researched - Both" }
    gui_style(label, { font = "heading-2" })
    scrollpanel.add { type = "table", name = "completed_research", column_count = 18 }
    update_research_info_element(player.gui.center["research_info_frame"])
end

function ResearchInfo.research_info_click(player, element)
    local elt = element
    while elt do
        if elt.name == "research_info_frame" then
            player.gui.center["research_info_frame"].destroy()
            return true
        end
        elt = elt.parent
    end
    if element.name == "research_info_button" then
        if player.gui.center["research_info_frame"] then
            player.gui.center["research_info_frame"].destroy()
            return true
        else
            ResearchInfo.show_research_info(player)
            return true
        end
    end
end

return ResearchInfo
