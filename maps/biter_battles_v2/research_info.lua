local gui_style = require 'utils.utils'.gui_style
local Functions = require 'maps.biter_battles_v2.functions'

local Public = {}

function Public.create_research_info_button(element, player)
    local b = element.add({type = "sprite-button", sprite = "item/space-science-pack", name = "research_info_button", tooltip = "Science Info"})
    gui_style(b, {width = 18, height = 18, padding = -2})
end

---@param force string
---@param tech_name string
function Public.research_finished(tech_name, force)
    local force_name = force.name
    if force_name ~= "north" and force_name ~= "south" then return end
    local tech_info = global.research_info.completed[tech_name]
    if not tech_info then
        tech_info = {}
        global.research_info.completed[tech_name] = tech_info
    end
    tech_info[force_name] = Functions.get_ticks_since_game_start()
    global.research_info.current_progress[force_name][tech_name] = nil
end

---@param force string
---@param tech_name string
function Public.research_started(tech_name, force)
    local force_name = force.name
    if force_name ~= "north" and force_name ~= "south" then return end
    global.research_info.current_progress[force_name][tech_name] = true
end

---@param force LuaForce
---@param tech_name string
function Public.research_reversed(tech_name, force)
    if force.name ~= "north" and force.name ~= "south" then return end
    local tech_info = global.research_info.completed[tech_name]
    if not tech_info then return end
    tech_info[force.name] = nil
end

---@param element LuaGuiElement
---@param filter_fn function
local function add_completed_research_icons(element, all_technologies, filter_fn)
    local icons_to_add = {}
    for tech_name, tech_info in pairs(global.research_info.completed) do
        if filter_fn(tech_name, tech_info) then
            local tooltip = {"", all_technologies[tech_name].localised_name}
            local time = math.huge
            if tech_info.north then
                table.insert(tooltip, "\nNorth: " .. Functions.format_ticks_as_time(tech_info.north))
                time = math.min(time, tech_info.north)
            end
            if tech_info.south then
                table.insert(tooltip, "\nSouth: " .. Functions.format_ticks_as_time(tech_info.south))
                time = math.min(time, tech_info.south)
            end
            local icon = {type = "sprite", sprite = "technology/" .. tech_name, tooltip = tooltip}
            table.insert(icons_to_add, {time = time, icon = icon})
        end
    end
    table.sort(icons_to_add, function(a, b) return a.time < b.time end)
    for _, icon in ipairs(icons_to_add) do
        local tech = element.add(icon.icon)
        gui_style(tech, {width = 38, height = 38, padding = -2, stretch_image_to_widget_size = true})
    end
end

---@param element LuaGuiElement
---@param force LuaForce
local function add_research_queue_icons(element, force, all_technologies)
    local queue = force.research_queue
    if not queue or #queue == 0 then return end
    local icons_to_add = {}
    for _, tech in ipairs(queue) do
        local tooltip = tech.localised_name
        local time = math.huge
        local icon = {type = "sprite", sprite = "technology/" .. tech.name, tooltip = tooltip}
        table.insert(icons_to_add, {time = time, icon = icon})
    end
    local t = element.add {type = "table", column_count = #icons_to_add + 1}
    t.add {type = "label", caption = "Queue: "}
    for _, icon in ipairs(icons_to_add) do
        local tech = t.add(icon.icon)
        gui_style(tech, {width = 38, height = 38, padding = -2, stretch_image_to_widget_size = true})
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
            local tooltip = all_technologies[tech_name].localised_name
            local icon = {type = "sprite", sprite = "technology/" .. tech_name, tooltip = tooltip}
            table.insert(icons_to_add, {icon = icon, progress = progress})
        end
    end
    -- Just alphabetical sort by technology name so that the order is stable
    table.sort(icons_to_add, function(a, b) return a.icon.sprite < b.icon.sprite end)
    for _, icon in ipairs(icons_to_add) do
        local horizontal_flow = element.add {type = "flow", direction = "horizontal"}
        gui_style(horizontal_flow, {vertical_align = "center"})
        local tech = horizontal_flow.add(icon.icon)
        gui_style(tech, {width = 38, height = 38, padding = -2, stretch_image_to_widget_size = true})
        horizontal_flow.add {type = "label", caption = string.format("%.0f%% complete", icon.progress * 100)}
    end
end

function Public.show_research_info(player)
    local all_technologies = game.forces.spectator.technologies
    if player.gui.center["research_info_frame"] then
        player.gui.center["research_info_frame"].destroy()
        return
    end
    local frame = player.gui.center.add {type = "frame", name = "research_info_frame", direction = "vertical"}
    gui_style(frame, {padding = 8})
    local scrollpanel = frame.add { type = "scroll-pane", name = "scroll_pane", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"}
    local label
    local horizontal_flow = scrollpanel.add {type = "flow", direction = "horizontal"}
    label = horizontal_flow.add {type = "label", caption = "Research Summary for both teams"}
    gui_style(label, {font = "heading-1"})
    local button = horizontal_flow.add({
        type = "button",
        name = "research_info_close",  -- clicking on any element works to close
        caption = "Close",
        tooltip = "Close this window."
    })
    button.style.font = "heading-3"
    label = scrollpanel.add {type = "label", caption = "North Current"}
    gui_style(label, {font = "heading-2"})
    add_research_queue_icons(scrollpanel, game.forces.north, all_technologies)
    add_research_progress_icons(scrollpanel, game.forces.north)
    label = scrollpanel.add {type = "label", caption = "South Current"}
    gui_style(label, {font = "heading-2"})
    add_research_queue_icons(scrollpanel, game.forces.south, all_technologies)
    add_research_progress_icons(scrollpanel, game.forces.south)

    label = scrollpanel.add {type = "label", caption = "Completed - Just North"}
    gui_style(label, {font = "heading-2"})
    add_completed_research_icons(scrollpanel.add {type = "table", column_count = 15},
    all_technologies,
    function(tech_name, tech_info) return tech_info.north and not tech_info.south end)
    label = scrollpanel.add {type = "label", caption = "Completed - Just South"}
    gui_style(label, {font = "heading-2"})
    add_completed_research_icons(scrollpanel.add {type = "table", column_count = 15},
    all_technologies,
    function(tech_name, tech_info) return not tech_info.north and tech_info.south end)
    label = scrollpanel.add {type = "label", caption = "Completed - Both"}
    gui_style(label, {font = "heading-2"})
    add_completed_research_icons(scrollpanel.add {type = "table", column_count = 15},
    all_technologies,
    function(tech_name, tech_info) return tech_info.north and tech_info.south end)
end

function Public.research_info_click(player, element)
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
            Public.show_research_info(player)
            return true
        end
    end
end

return Public
