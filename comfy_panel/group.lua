-- this script adds a group button to create groups for your players --

local Tabs = require('comfy_panel.main')
local Global = require('utils.global')
local Color = require('utils.color_presets')

local this = {
    player_group = {},
    join_spam_protection = {},
    tag_groups = {},
    alphanumeric = true,
}

Global.register(this, function(t)
    this = t
end)

local Public = {}

---Add __ to protect from overlapping with LuaGuiElement properties
---@param name_in string
---@return string
function Public.convert_to_safe_group_name(name_in)
    return '__' .. name_in
end

---Remove __ to protect from overlapping with LuaGuiElement properties
---@param name_in string
---@return string
function Public.convert_from_safe_group_name(name_in)
    return name_in:sub(3)
end

Public.COMFY_PANEL_CAPTAINS_GROUP_PREFIX = 'cpt_'
---@comment safe == '__' prepended
Public.COMFY_PANEL_CAPTAINS_SAFE_GROUP_PREFIX =
    Public.convert_to_safe_group_name(Public.COMFY_PANEL_CAPTAINS_GROUP_PREFIX)
Public.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX = '[' .. Public.COMFY_PANEL_CAPTAINS_GROUP_PREFIX

---@param player LuaPlayer
---@param frame LuaGuiElement
local build_group_gui = function(player, frame)
    local group_name_width = 150
    local description_width = 240
    local members_width = 90
    local member_columns = 3
    local actions_width = 80
    local total_height = frame.style.minimal_height - 60

    frame.clear()

    local t = frame.add({ type = 'table', column_count = 5 })
    local headings = {
        { 'Title', group_name_width },
        { 'Description', description_width },
        { 'Members', members_width * member_columns },
        { '', actions_width },
    }
    for _, h in pairs(headings) do
        local l = t.add({ type = 'label', caption = h[1] })
        l.style.font_color = { r = 0.98, g = 0.66, b = 0.22 }
        l.style.font = 'default-listbox'
        l.style.top_padding = 6
        l.style.minimal_height = 40
        l.style.minimal_width = h[2]
        l.style.maximal_width = h[2]
    end

    local scroll_pane = frame.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
    })
    scroll_pane.style.maximal_height = total_height - 50
    scroll_pane.style.minimal_height = total_height - 50

    local t = scroll_pane.add({ type = 'table', name = 'groups_table', column_count = 4 })
    for _, h in pairs(headings) do
        local l = t.add({ type = 'label', caption = '' })
        l.style.minimal_width = h[2]
        l.style.maximal_width = h[2]
    end

    for _, group in pairs(this.tag_groups) do
        if group.name and group.founder and group.description then
            local l = t.add({ type = 'label', caption = group.name })
            l.style.font = 'default-bold'
            l.style.top_padding = 16
            l.style.bottom_padding = 16
            l.style.minimal_width = group_name_width
            l.style.maximal_width = group_name_width
            local color
            if game.get_player(group.founder) and game.get_player(group.founder).color then
                color = game.get_player(group.founder).color
            else
                color = { r = 0.90, g = 0.90, b = 0.90 }
            end
            color = { r = color.r * 0.6 + 0.4, g = color.g * 0.6 + 0.4, b = color.b * 0.6 + 0.4, a = 1 }
            l.style.font_color = color
            l.style.single_line = false
            local l = t.add({ type = 'label', caption = group.description })
            l.style.top_padding = 16
            l.style.bottom_padding = 16
            l.style.minimal_width = description_width
            l.style.maximal_width = description_width
            l.style.font_color = { r = 0.90, g = 0.90, b = 0.90 }
            l.style.single_line = false

            local tt = t.add({ type = 'table', column_count = member_columns })
            for _, p in pairs(game.connected_players) do
                if group.name == this.player_group[p.name] then
                    local l = tt.add({ type = 'label', caption = p.name })
                    local color = {
                        r = p.color.r * 0.6 + 0.4,
                        g = p.color.g * 0.6 + 0.4,
                        b = p.color.b * 0.6 + 0.4,
                        a = 1,
                    }
                    l.style.font_color = color
                    --l.style.minimal_width = members_width
                    l.style.maximal_width = members_width * 2
                end
            end

            local group_lua_id = Public.convert_to_safe_group_name(group.name)
            local tt = t.add({ type = 'table', name = group_lua_id, column_count = 1 })
            if group.name ~= this.player_group[player.name] then
                local b = tt.add({ type = 'button', caption = 'Join' })
                b.style.font = 'default-bold'
                b.style.minimal_width = actions_width
                b.style.maximal_width = actions_width
            else
                local b = tt.add({ type = 'button', caption = 'Leave' })
                b.style.font = 'default-bold'
                b.style.minimal_width = actions_width
                b.style.maximal_width = actions_width
            end
            if is_admin(player) or group.founder == player.name then
                local b = tt.add({ type = 'button', caption = 'Delete' })
                b.style.font = 'default-bold'
                b.style.minimal_width = actions_width
                b.style.maximal_width = actions_width
            else
                local l = tt.add({ type = 'label', caption = '' })
                l.style.minimal_width = actions_width
                l.style.maximal_width = actions_width
            end
        end
    end

    frame.style.bottom_padding = 0
    local frame2 = frame.add({ type = 'frame', name = 'frame2' })
    frame2.style.margin = 0
    frame2.style.bottom_padding = 4
    frame2.style.horizontally_stretchable = true
    local t = frame2.add({ type = 'table', name = 'group_table', column_count = 3 })
    local textfield = t.add({ type = 'textfield', name = 'new_group_name', text = 'Name' })
    textfield.style.minimal_width = 200
    local textfield = t.add({ type = 'textfield', name = 'new_group_description', text = 'Description' })
    textfield.style.horizontally_stretchable = true
    textfield.style.natural_width = 0
    textfield.style.width = 0
    local b = t.add({ type = 'button', name = 'create_new_group', caption = 'Create' })
    b.style.minimal_width = 150
    b.style.font = 'default-bold'
end

---@param text string
---@param prefix string
---@return boolean
local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function refresh_gui()
    for _, p in pairs(game.connected_players) do
        local frame = Tabs.comfy_panel_get_active_frame(p)
        if frame then
            if frame.name == 'Groups' then
                local new_group_name = frame.frame2.group_table.new_group_name.text
                local new_group_description = frame.frame2.group_table.new_group_description.text

                if new_group_name:len() > 30 then
                    new_group_name = string.sub(new_group_name, 1, 30)
                end

                if new_group_description:len() > 60 then
                    new_group_description = string.sub(new_group_description, 1, 60)
                end
                build_group_gui(p, frame)

                local frame = Tabs.comfy_panel_get_active_frame(p)
                frame.frame2.group_table.new_group_name.text = new_group_name
                frame.frame2.group_table.new_group_description.text = new_group_description
            end
        end
    end
end

---@param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)

    if not this.player_group[player.name] then
        this.player_group[player.name] = '[Group]'
    end

    if not this.join_spam_protection[player.name] then
        this.join_spam_protection[player.name] = game.tick
    end
end

---@param event EventData.on_gui_text_changed
local function on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid then
        return
    end

    local name = element.name
    local text = element.text

    if name == 'new_group_name' then
        if text:len() > 30 then
            element.text = string.sub(element.text, 1, 30)
        end
    end
    if name == 'new_group_description' then
        if text:len() > 60 then
            element.text = string.sub(element.text, 1, 60)
        end
    end
end

---@param str string
---@return boolean
local function alphanumeric(str)
    -- prohibit []()= because they are confusing in the UI and allow factorio rich text injection
    return string.match(str, '^[%w%s%p]*$') ~= nil and string.match(str, '[%(%)%[%]%=]') ~= nil
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
    if not event then
        return
    end
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end

    local player = game.get_player(event.element.player_index)
    local name = event.element.name
    local frame = Tabs.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end
    if frame.name ~= 'Groups' then
        return
    end

    if name == 'create_new_group' then
        local new_group_name = frame.frame2.group_table.new_group_name.text
        local new_group_description = frame.frame2.group_table.new_group_description.text
        if new_group_name ~= '' and new_group_name ~= 'Name' and new_group_description ~= 'Description' then
            if this.alphanumeric then
                if alphanumeric(new_group_name) then
                    player.print('Group name is not valid.', { color = { r = 0.90, g = 0.0, b = 0.0 } })
                    return
                end

                if alphanumeric(new_group_description) then
                    player.print('Group description is not valid.', { color = { r = 0.90, g = 0.0, b = 0.0 } })
                    return
                end
            end

            if string.len(new_group_name) > 64 then
                player.print(
                    'Group name is too long. 64 characters maximum.',
                    { color = { r = 0.90, g = 0.0, b = 0.0 } }
                )
                return
            end

            if string.len(new_group_description) > 128 then
                player.print(
                    'Description is too long. 128 characters maximum.',
                    { color = { r = 0.90, g = 0.0, b = 0.0 } }
                )
                return
            end

            if this.tag_groups[new_group_name] ~= nil then
                player.print('Group name is taken.', { color = { r = 0.90, g = 0.0, b = 0.0 } })
                return
            end

            this.tag_groups[new_group_name] = {
                name = new_group_name,
                description = new_group_description,
                founder = player.name,
            }
            local color = {
                r = player.color.r * 0.7 + 0.3,
                g = player.color.g * 0.7 + 0.3,
                b = player.color.b * 0.7 + 0.3,
                a = 1,
            }
            game.print(player.name .. ' has founded a new group!', { color = color })
            game.print('>> ' .. new_group_name, { color = { r = 0.98, g = 0.66, b = 0.22 } })
            game.print(new_group_description, { color = { r = 0.85, g = 0.85, b = 0.85 } })

            frame.frame2.group_table.new_group_name.text = 'Name'
            frame.frame2.group_table.new_group_description.text = 'Description'
            refresh_gui()
            return
        end
    end

    local p = event.element.parent
    if p then
        p = p.parent
    end
    if p then
        if p.name == 'groups_table' then
            if event.element.type == 'button' and event.element.caption == 'Join' then
                local safe_group_name = event.element.parent.name
                local group_name = Public.convert_from_safe_group_name(safe_group_name)
                if
                    (
                        storage.active_special_games['captain_mode']
                        and storage.special_games_variables['captain_mode']['pickingPhase']
                        and startswith(group_name, Public.COMFY_PANEL_CAPTAINS_GROUP_PREFIX)
                    )
                    or (
                        storage.active_special_games['captain_mode']
                        and storage.special_games_variables['captain_mode']['pickingPhase']
                        and startswith(player.tag, Public.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX)
                    )
                then
                    player.print('You cant join or leave a picking group during picking phase..', { color = Color.red })
                else
                    local player_group_tag = '[' .. group_name .. ']'
                    this.player_group[player.name] = group_name
                    player.tag = player_group_tag
                    if game.tick - this.join_spam_protection[player.name] > 600 then
                        local color = {
                            r = player.color.r * 0.7 + 0.3,
                            g = player.color.g * 0.7 + 0.3,
                            b = player.color.b * 0.7 + 0.3,
                            a = 1,
                        }
                        game.print(player.name .. ' has joined group "' .. group_name .. '"', { color = color })
                        this.join_spam_protection[player.name] = game.tick
                    end
                    refresh_gui()
                end
                return
            end

            if event.element.type == 'button' and event.element.caption == 'Delete' then
                local safe_group_name = event.element.parent.name
                local group_name = Public.convert_from_safe_group_name(safe_group_name)
                if
                    storage.active_special_games['captain_mode']
                    and storage.special_games_variables['captain_mode']['pickingPhase']
                    and startswith(group_name, Public.COMFY_PANEL_CAPTAINS_GROUP_PREFIX)
                then
                    player.print('You cant delete a picking group during picking phase..', { color = Color.red })
                else
                    for _, p in pairs(game.players) do
                        if this.player_group[p.name] then
                            if this.player_group[p.name] == group_name then
                                this.player_group[p.name] = '[Group]'
                                p.tag = ''
                            end
                        end
                    end
                    game.print(player.name .. ' deleted group "' .. group_name .. '"')
                    this.tag_groups[group_name] = nil
                    refresh_gui()
                end
                return
            end

            if event.element.type == 'button' and event.element.caption == 'Leave' then
                if
                    storage.active_special_games['captain_mode']
                    and storage.special_games_variables['captain_mode']['pickingPhase']
                    and startswith(player.tag, Public.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX)
                then
                    player.print('You cant leave a picking group during picking phase..', { color = Color.red })
                else
                    this.player_group[player.name] = '[Group]'
                    player.tag = ''
                    refresh_gui()
                end
                return
            end
        end
    end
end

function Public.alphanumeric_only(value)
    if value then
        this.alphanumeric = value
    else
        this.alphanumeric = false
    end
end

function Public.reset_groups()
    this.player_group = {}
    this.join_spam_protection = {}
    this.tag_groups = {}
end

comfy_panel_tabs['Groups'] = { gui = build_group_gui, admin = false }

local event = require('utils.event')
event.add(defines.events.on_gui_click, on_gui_click)
event.add(defines.events.on_player_joined_game, on_player_joined_game)
event.add(defines.events.on_gui_text_changed, on_gui_text_changed)

return Public
