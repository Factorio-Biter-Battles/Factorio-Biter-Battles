local gui_style = require 'utils.utils'.gui_style
local flui = require 'utils.ui.gui-lite'
local uic = require 'utils.ui.fcomponents'
local Event = require 'utils.event'
local Functions = require 'maps.biter_battles_v2.functions'
local closable_frame = require "utils.ui.closable_frame"

local MAXHEIGHT_PADDING = 50

local function ui_template()
    --[[
        research_info_ui
            scroll
                main
    ]]
    local container = uic.blocks.vflow "main"
    local teams = uic.add(container,
        uic.blocks.hflow "teams"
    )
    teams.style_mods = { vertically_stretchable = true }
    for _, name in ipairs { "north", "south" } do
        uic.add(teams, {
            type = "frame",
            style = "inside_shallow_frame_with_padding",
            direction = "vertical",
            name = name,
            style_mods = {
                natural_width = 365,
                padding = { 8, 12, 12, 12 },
                vertically_stretchable = true,
            },
            children = {
                {
                    type = "label",
                    caption = "UPDATE ME",
                    name = "team_name_"..name,
                    style_mods = {
                        font = "heading-1"
                    }
                },
                {
                    type = "label",
                    caption = "Current Queue",
                    style_mods = {
                        font = "heading-2"
                    }
                },
                {
                    type = "frame",
                    direction = "vertical",
                    name = "queue_frame",
                    style = "deep_frame_in_shallow_frame",
                    style_mods = {
                        padding = 4,
                        horizontally_stretchable = true,
                        bottom_margin = 4
                    },
                    {
                        type = "flow",
                        name = "queue",
                        style_mods = {
                            padding = 0
                        },
                        {
                            type = "label",
                            caption = "Loading..."
                        }
                    }
                },
                {
                    type = "frame",
                    direction = "vertical",
                    name = "progress_frame",
                    style = "deep_frame_in_shallow_frame",
                    style_mods = {
                        padding = 4,
                        horizontally_stretchable = true,
                        bottom_margin = 4
                    },
                    {
                        type = "table",
                        name = "progress",
                        column_count = 15,
                        style_mods = {
                            horizontally_stretchable = false
                        },
                        {
                            type = "label",
                            caption = "Loading..."
                        }
                    }
                },
                {
                    type = "label",
                    caption = "Researched (exclusive)",
                    style_mods = {
                        font = "heading-2"
                    }
                },
                {
                    type = "frame",
                    direction = "vertical",
                    name = "completed_frame",
                    style = "deep_frame_in_shallow_frame",
                    style_mods = {
                        padding = 4,
                        horizontally_stretchable = true,
                        bottom_margin = 4
                    },
                    {
                        type = "table",
                        name = "completed",
                        column_count = 8,
                        {
                            type = "label",
                            caption = "Loading..."
                        }
                    }

                }
            }
        })
    end
    local both_teams = uic.add(container, {
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
        name = "both_teams",
        {
            type = "label",
            caption = "Researched (both)",
            style_mods = {
                font = "heading-1"
            }
        },
        {
            type = "frame",
            direction = "vertical",
            name = "completed_frame",
            style = "deep_frame_in_shallow_frame",
            style_mods = {
                padding = 4,
                horizontally_stretchable = true,
                bottom_margin = 4
            },
            {
                type = "table",
                name = "completed_both",
                column_count = 18,
                {
                    type = "label",
                    caption = "Loading..."
                }
            }
        }
    })
    return container
end
local UI = ui_template()

---@param tech_id string
---@param north_desc string | nil
---@param south_desc string | nil
---@return GuiElemDef
local function research_item(tech_id, north_desc, south_desc)
    local tooltip_items = {}
    table.insert(tooltip_items, "North: " .. (north_desc or "Not started"))
    table.insert(tooltip_items, "South: " .. (south_desc or "Not started"))
    ---@type GuiElemDef
    return {
        type = "sprite",
        sprite = "technology/" .. tech_id,
        tooltip = table.concat(tooltip_items, "\n"),
        elem_tooltip = { type = "technology", name = tech_id },
        name = "_" .. tech_id,
        tags = {
            -- match compatibility with progress_research_item
            sort_by = tech_id,
            tech_id = tech_id
        },
        style_mods = {
            width = 38,
            height = 38,
            padding = 0,
            stretch_image_to_widget_size = true
        }
    }
end

---Research item with progress percentage.
---@param tech_id string
---@param this_progress number
---@param is_active boolean
---@param north_desc string | nil
---@param south_desc string | nil
---@return GuiElemDef
local function progress_research_item(tech_id, this_progress, is_active, north_desc, south_desc)
    local tooltip_items = {}
    table.insert(tooltip_items, "North: " .. (north_desc or "Not started"))
    table.insert(tooltip_items, "South: " .. (south_desc or "Not started"))
    ---@type GuiElemDef
    local el = {
        type = "flow",
        direction = "vertical",
        name = "_" .. tech_id,
        style_mods = {
            vertical_spacing = 0,
            width = 38
        },
        tags = {
            sort_by = tech_id,
            tech_id = tech_id
        },
        research_item(tech_id, north_desc, south_desc),
        {
            type = "progressbar",
            value = this_progress,
            tooltip = table.concat(tooltip_items, "\n"),
            style_mods = {
                color = is_active and { 0, 1, 0 } or { 1, 1, 0 }
            }
        }
    }
    return el
end

local ResearchInfo = {}

---@param evt GuiEventData
function ResearchInfo.show_research_info_handler(evt)
    local player = game.get_player(evt.player_index)
    ResearchInfo.show_research_info(player)
end
local show_research_info_handler = ResearchInfo.show_research_info_handler

flui.add_handlers {
    research_info_button_click = show_research_info_handler
}

function ResearchInfo.create_research_info_button(element)
    ---@type GuiElemDef
    local template = {
        type = "sprite-button",
        sprite = "item/lab",
        name = "research_info_button",
        tooltip = "Science Info",
        style = "transparent_slot",
        style_mods = {
            width = 26,
            height = 26,
            padding = 2
        },
        handler = show_research_info_handler
    }
    local _, button = flui.add(element, template)
    return button
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

    ResearchInfo.update_research_info_ui(true)
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
    ResearchInfo.update_research_info_ui(true)
end

local function get_research_info(tech_id)
    local tech_info = global.research_info.completed[tech_id]
    local progress = global.research_info.current_progress

    ---@param force LuaForce
    ---@return string?, number?, boolean
    local function format(force)
        local all_technologies = force.technologies
        local force_name = force.name
        ---@type string?
        local result = nil
        ---@type number?
        local progress
        local active = false
        if tech_info and tech_info[force_name] then
            result = Functions.format_ticks_as_time(tech_info[force_name])
        else
            local current = force.current_research
            ---@type string?
            local type
            if current and current.name == tech_id then
                type = "In progress - "
                progress = force.research_progress
                active = true
            else
                type = "Paused - "
                progress = force.get_saved_technology_progress(all_technologies[tech_id])
            end
            if progress then
                result = type .. string.format("%.0f%% complete", progress * 100)
            end
        end
        return result, progress, active
    end

    local north, north_pct, north_active = format(game.forces.north)
    local south, south_pct, south_active = format(game.forces.south)
    return {
        north = {
            desc = north,
            pct = north_pct,
            active = north_active
        },
        south = {
            desc = south,
            pct = south_pct,
            active = south_active
        }
    }
end

---@param filter fun(tech_name: string, tech_info: unknown): boolean
---@return GuiElemDef[]
local function construct_completed(filter)
    ---@type GuiElemDef[]
    local elements = {}
    for tech_name, tech_info in pairs(global.research_info.completed) do
        if filter(tech_name, tech_info) then
            local info = get_research_info(tech_name)
            elements[#elements + 1] = research_item(tech_name, info.north.desc, info.south.desc)
        end
    end
    table.sort(elements, function(a, b) return a.tags.sort_by < b.tags.sort_by end)
    if #elements == 0 then
        elements[#elements + 1] = uic.blocks.label "No results"
    end
    return elements
end

---@param force LuaForce
---@return GuiElemDef
local function construct_research_queue(force)
    local queue_data = force.research_queue
    local queue_elem = uic.blocks.hflow "queue"

    if not queue_data or #queue_data == 0 then
        uic.add(queue_elem, uic.blocks.label "Nothing queued")
    else
        for _, tech in ipairs(queue_data) do
            local research_info = get_research_info(tech.name)
            uic.add(queue_elem, research_item(
                tech.name,
                research_info.north.desc,
                research_info.south.desc
            ))
        end
    end
    return queue_elem
end

---@param force LuaForce
---@return GuiElemDef
local function construct_progress(force)
    local progress_info = global.research_info.current_progress[force.name]
    local el = uic.blocks.table(15, "progress")
    local matches = 0
    for tech_name, _ in pairs(progress_info) do
        local tech_info = get_research_info(tech_name)
        local progress = tech_info[force.name].pct
        local active = tech_info[force.name].active or false
        if progress then
            matches = matches + 1
            uic.add(el, progress_research_item(tech_name, progress, active, tech_info.north.desc, tech_info.south.desc))
        end
    end
    if matches == 0 then
        uic.add(el, uic.blocks.label "No partially complete research")
    end
    return el
end

---@alias research_info.ui_update_package.team { queue: GuiElemDef, progress: GuiElemDef, excl_completed: GuiElemDef[] }

---@class research_info.ui_update_package
---@field north? research_info.ui_update_package.team
---@field south? research_info.ui_update_package.team
---@field both_completed? GuiElemDef[]

---@class research_info.ui_update_package.concrete : research_info.ui_update_package
---@field north research_info.ui_update_package.team
---@field south research_info.ui_update_package.team
---@field both_completed GuiElemDef[]

---@param element LuaGuiElement
---@param package research_info.ui_update_package.concrete
---@param completed_technologies_changed boolean?
local function update_research_info_element(element, package, completed_technologies_changed)
    local frame_teams = element.teams
    for _, force in pairs { "north", "south" } do
        local team_data = package[force] --[[@as research_info.ui_update_package.team]]
        local team_frame = frame_teams[force]
        team_frame.queue_frame.queue.destroy()
        flui.add(team_frame.queue_frame, team_data.queue)
        team_frame.progress_frame.progress.destroy()
        flui.add(team_frame.progress_frame, team_data.progress)

        if completed_technologies_changed then
            team_frame.completed_frame.completed.clear()
            for _, v in pairs(team_data.excl_completed) do
                flui.add(team_frame.completed_frame.completed, v)
            end
        end
    end

    local both = element.both_teams
    if not both then return end

    if completed_technologies_changed then
        both.completed_frame.completed_both.clear()
        for _, v in pairs(package.both_completed) do
            flui.add(both.completed_frame.completed_both, v)
        end
    end
end

---@param player LuaPlayer
---@param element LuaGuiElement
local function update_research_info_size(player, element)
    local eff = player.display_resolution.height / player.display_scale
    element.style.maximal_height = eff - (MAXHEIGHT_PADDING * 2)
end

---@return research_info.ui_update_package.concrete
local function calculate_ui()
    ---@type research_info.ui_update_package
    local data = {}
    for team, opposition in pairs { north = "south", south = "north" } do
        local force = game.forces[team]
        data[team] = {
            queue = construct_research_queue(force),
            progress = construct_progress(force),
            excl_completed = construct_completed(function(_, info)
                return info[team] and not info[opposition]
            end)
        }
    end
    data.both_completed = construct_completed(function(_, info)
        return info.north and info.south
    end)
    ---@cast data research_info.ui_update_package.concrete
    return data
end

---@param completed_technologies_changed boolean?
function ResearchInfo.update_research_info_ui(completed_technologies_changed)
    local data = calculate_ui()
    for _, player in pairs(game.connected_players) do
        if player.gui.screen["research_info_frame"] then
            update_research_info_element(player.gui.screen["research_info_frame"].scroll.main, data, completed_technologies_changed)
        end
    end
end

---@param player LuaPlayer
function ResearchInfo.show_research_info(player)
    local all_technologies = game.forces.spectator.technologies
    local frame = player.gui.screen["research_info_frame"]

    if frame and frame.valid then
        --player.gui.screen["research_info_frame"].bring_to_front()
        --player.gui.screen["research_info_frame"].force_auto_center()
        if player.opened == frame then
            player.opened = nil
        end
        frame.destroy()
        return
    end

    frame = closable_frame.create_main_closable_frame(player, "research_info_frame", "Research summary for both teams")
    local scroll = frame.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "always", name = "scroll" })
    local named_elements = flui.add(scroll, UI)
    named_elements["team_name_south"].caption = Functions.team_name_with_color("south")
    named_elements["team_name_north"].caption = Functions.team_name_with_color("north")
    local el = player.gui.screen["research_info_frame"]
    update_research_info_size(player, el)
    local data = calculate_ui()
    -- full refresh needed to populate the UI
    update_research_info_element(el.scroll.main, data, true)
end

---@param evtd EventData.on_player_display_resolution_changed | EventData.on_player_display_scale_changed
local function on_display_changed(evtd)
    local player = game.get_player(evtd.player_index)
    if not player then return end
    local el = player.gui.screen["research_info_frame"]
    if not el then return end
    update_research_info_size(player, el)
    el.force_auto_center()
end

Event.add(defines.events.on_player_display_resolution_changed, on_display_changed)
Event.add(defines.events.on_player_display_scale_changed, on_display_changed)

return ResearchInfo
