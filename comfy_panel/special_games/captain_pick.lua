local CaptainUtils = require('comfy_panel.special_games.captain_utils')
local Color = require('utils.color_presets')
local Event = require('utils.event')
local Gui = require('utils.gui')
local Session = require('utils.datastore.session_data')
local Token = require('utils.token')
local table = require('utils.table')

local math_floor = math.floor
local string_find = string.find
local string_format = string.format
local string_sub = string.sub
local table_add_all = table.add_all
local table_concat = table.concat
local table_deepcopy = table.deepcopy
local table_insert = table.insert
local table_sort = table.sort

-- == PLAYERMETA ==============================================================

local PlayerMeta = {}

---@param p LuaPlayer|PlayerMeta
function PlayerMeta.new(p)
    if p.print then
        p = { player = p }
    end

    return {
        ---@type string
        name = p.player.name,
        ---@type integer
        index = p.player.index,
        ---@type LuaPlayer
        player = p.player,
        ---@type number
        value = p.value or 0,
        ---@type string
        value_tooltip = p.value_tooltip or '',
        ---@type number
        rank = p.rank or 12,
        ---@type number
        weight = p.weight or 0,
        ---@type number
        playtime = p.playtime or 0,
        ---@type string
        note = p.note or '',
        ---@type table<string, boolean>
        tasks = table_deepcopy(p.tasks or {}),
        ---@type table<integer, number>
        votes = table_deepcopy(p.votes or {}),
    }
end

---@param self PlayerMeta
function PlayerMeta.update(self)
    PlayerMeta.get_playtime(self)
    PlayerMeta.get_weight(self)
    return self
end

---@param self PlayerMeta
function PlayerMeta.get_playtime(self)
    self.playtime = storage.total_time_online_players[self.name] or 0
    return self.playtime
end

---@param self PlayerMeta
function PlayerMeta.get_value(self)
    self.value = 0
    for _, v in pairs(self.votes) do
        self.value = self.value + v
    end
    return self.value
end

---@param self PlayerMeta
function PlayerMeta.get_weight(self)
    self.weight = math.ceil(math.sqrt(2) ^ (math.max(0, 12 - self.rank)))
    return self.weight
end

-- ===========================================================================

local Public = {}

-- == SETUP ===================================================================

local main_frame_name = Gui.uid_name()
local minimize_button_name = Gui.uid_name()
local settings_button_name = Gui.uid_name()
local settings_frame_name = Gui.uid_name()
local searchbox_name = Gui.uid_name()
local enrollment_flow_name = Gui.uid_name()

local action_toggle_task = Gui.uid_name()
local action_toggle_task_filter = Gui.uid_name()
local action_reset_task_filter = Gui.uid_name()
local action_cast_vote = Gui.uid_name()
local action_mark_favourite = Gui.uid_name()
local action_pick_player = Gui.uid_name()
local action_refresh_list = Gui.uid_name()
local action_show_info = Gui.uid_name()
local action_sort_by = Gui.uid_name()

local draft_timer_favor = Gui.uid_name()
local draft_timer_enable = Gui.uid_name()
local draft_timer_disable = Gui.uid_name()
local draft_timer_pause = Gui.uid_name()
local draft_timer_unpause = Gui.uid_name()
local draft_timer_change = Gui.uid_name()

local SECOND = 60
local MINUTE = 60 * SECOND
local HOUR = 60 * MINUTE
local DEFAULT = {
    time_fixed = 8 * MINUTE,
    time_increment = 10 * SECOND,
    sorting = { 'Playtime', 'Name', 'Value' },
    tasks = {
        'assembling-machine-2',
        'electric-mining-drill',
        'grenade',
        'lab',
        'laser-turret',
        'nuclear-reactor',
        'pumpjack',
        'rocket-part',
        'steam-engine',
        'stone-wall',
    },
    max_note_length = 300,
}
local Comparators = {
    Name = function(a, b)
        return a.name:lower() < b.name:lower()
    end,
    Playtime = function(a, b)
        return a.playtime > b.playtime
    end,
    Value = function(a, b)
        return a.value > b.value
    end,
    Rank = function(a, b)
        return a.rank < b.rank
    end,
}
local Icons = {
    favourite_enabled = '[img=virtual-signal/signal-star]',
    favourite_disabled = '[img=virtual-signal/signal-damage;tint=55,55,55,0]',
    left_arrow_enabled = '[img=virtual-signal/left-arrow]',
    left_arrow_disabled = '[img=virtual-signal/left-arrow;tint=55,55,55,0]',
    right_arrow_enabled = '[img=virtual-signal/right-arrow]',
    right_arrow_disabled = '[img=virtual-signal/right-arrow;tint=55,55,55,0]',
}

---@type table<integer, table<string, boolean>>
local player_preferences = {}
---@type table<integer, table<integer, boolean>>
local favourites = {}
---@type table<integer, number>
local debounce = {}

local this = {
    -- Settings
    enabled = false,
    turn = false,
    next_update = 0,
    uptime = 0,
    north = { list = {} },
    south = { list = {} },
    spectator = { list = {} },

    -- Draft timer
    time_paused = false,
    time_fixed = 0,
    time_increment = 0,
}

Event.on_init(function()
    storage.captainPick = {
        this = this,
        debounce = debounce,
        favourites = favourites,
        player_preferences = player_preferences,
    }
end)
Event.on_load(function()
    this = storage.captainPick.this
    debounce = storage.captainPick.debounce
    favourites = storage.captainPick.favourites
    player_preferences = storage.captainPick.player_preferences
end)

Public.get = function(key)
    if key then
        return this[key]
    end
    return this
end

Public.enable = function(params)
    params = params or {}

    this.turn = params.turn or false
    this.uptime = 0
    this.time_fixed = params.time_fixed or DEFAULT.time_fixed
    this.time_increment = params.time_increment or DEFAULT.time_increment

    this.north = Public.get_force_settings(this.north.list)
    this.south = Public.get_force_settings(this.south.list)
    this.north.time = this.time_fixed
    this.south.time = this.time_fixed

    if not this.enabled then
        this.enabled = true
        Event.add_removable(defines.events.on_tick, Public.on_tick_token)
    end

    if not this.turn then
        this.turn = math.random() < 0.5 and 'north' or 'south'
    end

    local side = this[this.turn]
    side.picks = 1
    side.picked = 0
    side.rounds = 1

    for _, p in pairs(this.spectator.list) do
        for _, list in pairs({ this.north.list, this.south.list }) do
            local obj = PlayerMeta.new(p)
            list[obj.index] = obj
        end
    end

    Public.draw_all()
end

Public.disable = function()
    this.turn = false
    this.time_paused = false
    this.uptime = 0
    this.north = Public.get_force_settings()
    this.south = Public.get_force_settings()
    this.spectator.list = {}
    table.clear_table(debounce)
    table.clear_table(favourites)
    table.clear_table(player_preferences)

    local special = CaptainUtils.get_special()
    for _, name in pairs(special and special.listPlayers or {}) do
        CaptainUtils.remove_from_playerList(name)
    end

    if this.enabled then
        this.enabled = false
        Event.remove_removable(defines.events.on_tick, Public.on_tick_token)
    end

    Public.destroy_all()
end

-- == PLAYER MANAGER ==========================================================

---@param playerID integer|string
Public.get_player = function(playerID)
    local player = game.get_player(playerID)
    if not (player and player.valid) then
        return
    end

    for _, side in pairs({ this.spectator, this.north, this.south }) do
        if side.list[player.index] then
            return side.list[player.index]
        end
    end
end

---@param playerID integer|string
Public.add_player = function(playerID)
    local player = game.get_player(playerID)
    if not (player and player.valid) then
        return
    end

    if this.spectator.list[player.index] then
        return
    end

    for _, force in pairs({ this.spectator, this.north, this.south }) do
        local p = PlayerMeta.new(player)
        PlayerMeta.update(p)
        force.list[player.index] = p
    end

    Public.queue_update()
end

---@param playerID integer|string
Public.remove_player = function(playerID)
    local player = game.get_player(playerID)
    if not (player and player.valid) then
        return
    end

    this.spectator.list[player.index] = nil
    this.north.list[player.index] = nil
    this.south.list[player.index] = nil

    Public.queue_update()
end

---@param player_index integer
Public.pick_player = function(player_index)
    local p = this.spectator.list[player_index]
    if not p then
        return
    end

    local side = this[this.turn]

    --- Remove any references from all lists
    this.spectator.list[player_index] = nil
    this.north.list[player_index] = nil
    this.south.list[player_index] = nil

    --- Create new reference on correct team and switch player to it
    CaptainUtils.remove_from_playerList(p.name)
    CaptainUtils.switch_team_of_player(p.name, this.turn)
    p.rank = side.rounds
    PlayerMeta.get_weight(p)
    side.list[player_index] = p

    --- Remove player from all favourites lists
    for _, list_of in pairs(favourites) do
        list_of[player_index] = nil
    end

    Public.queue_update()
end

---@param player_index integer
---@param task_name string
Public.toggle_enrollment_task = function(player_index, task_name)
    local p = this.spectator.list[player_index]
    if not p then
        return
    end

    if p.tasks[task_name] then
        p.tasks[task_name] = nil
    else
        p.tasks[task_name] = true
    end
end

---@param actor_index integer
---@param target_index integer
---@param sign number
Public.cast_vote = function(actor_index, target_index, sign)
    local actor = Public.get_player(actor_index)
    if not actor then
        return
    end

    local side = actor.player.force.name
    local target = this[side].list and this[side].list[target_index] or this.spectator.list[target_index]
    if not target then
        return
    end

    local old_vote = target.votes[actor_index]
    local new_vote = sign * actor.weight

    if old_vote == new_vote then
        target.votes[actor_index] = nil
    else
        target.votes[actor_index] = new_vote
    end

    target.value_tooltip = Public.get_value_tooltip(target)
    PlayerMeta.get_value(target)
end

---@param player_index integer
---@param text string
Public.set_player_note = function(player_index, text)
    local p = this.spectator.list[player_index]
    if not p then
        return
    end

    if #text > DEFAULT.max_note_length then
        p.player.print(
            string_format('Player info must not exceed %d characters', DEFAULT.max_note_length),
            { color = Color.warning }
        )
        text = string_sub(text, 1, DEFAULT.max_note_length)
    end

    p.note = text
    return text
end

---@param playerID integer|string
---@param force_name string
Public.set_captain = function(playerID, force_name)
    local player = game.get_player(playerID)
    if not (player and player.valid) then
        return
    end

    local side = this[force_name]
    if not side then
        return
    end

    this.spectator.list[player.index] = nil
    this.north.list[player.index] = nil
    this.south.list[player.index] = nil

    local p = PlayerMeta.new(player)
    p.rank = 0
    p.weight = 5000
    side.list[player.index] = p

    CaptainUtils.switch_team_of_player(p.name, force_name)

    Public.queue_update()
end

-- == TIME MANAGER ============================================================

Public.pause = function()
    this.time_paused = true
end

Public.unpause = function()
    this.time_paused = false
end

Public.perform_auto_picks = function()
    local side = this[this.turn]
    local max_attempts = 5
    local cpt_index = false

    -- Cache cpt index
    if storage.special_games_variables.captain_mode then
        local list = storage.special_games_variables.captain_mode.captainList
        local captain = game.get_player(list[side == 'north' and 1 or 2])
        if captain and captain.valid then
            cpt_index = captain.index
        end
    end

    while (side.picks - side.picked > 1) and max_attempts > 0 do
        -- Build array of players from favourites, if any
        local candidates = cpt_index and Public.get_favourites_list(cpt_index) or {}

        -- Fallback to whole player list
        if #candidates == 0 then
            for _, p in pairs(side.list) do
                if p.player.force.name == 'spectator' then
                    table_insert(candidates, p.index)
                end
            end
        end

        if #candidates == 0 then
            return
        end

        -- Draw 1 at random
        local player_index = candidates[math.random(#candidates)]
        Public.pick_player(player_index)
        side.picked = side.picked + 1

        max_attempts = max_attempts - 1
    end

    Public.queue_update()
end

---@param side string 'north'|'south'
Public.switch_turn = function(side)
    this.turn = side or (this.turn == 'north' and 'south' or 'north')

    assert(this.turn == 'north' or this.turn == 'south', 'Picking turns can only belong to either north or south side.')

    local active = this[this.turn]
    active.time = active.time + this.time_increment
    active.picks = 2
    active.picked = 0
    active.rounds = active.rounds + 1

    local passive = this[this.turn == 'north' and 'south' or 'north']
    passive.picks = 0
    passive.picked = 0

    Public.queue_update()
end

---@param ticks number
Public.change_time = function(ticks)
    this.north.time = math.max(0, this.north.time + ticks)
    this.south.time = math.max(0, this.south.time + ticks)
end

local on_tick = function()
    if not this.enabled or this.time_paused then
        return
    end

    if this.next_update == game.tick then
        Public.update_all()
    end

    if not (game.tick % SECOND == 0) then
        return
    end

    if table_size(this.spectator.list) == 0 then
        Public.end_of_picking_phase()
        return
    end

    this.uptime = this.uptime + SECOND

    local side = this[this.turn]
    side.time = math.max(0, side.time - SECOND)
    if side.picked >= side.picks then
        Public.switch_turn()
    elseif side.time == 0 then
        Public.perform_auto_picks()
        Public.switch_turn()
    end

    local timer_info = {
        'captain.info_draft_timer',
        Public.format_time_short(this.uptime),
        Public.format_time_short(this.time_fixed),
        Public.format_time_short(this.time_increment),
    }
    local north_time = Public.format_time_short(this.north.time)
    local south_time = Public.format_time_short(this.south.time)
    local north_picks = { 'captain.info_picks', this.north.rounds, this.north.picked, this.north.picks }
    local south_picks = { 'captain.info_picks', this.south.rounds, this.south.picked, this.south.picks }
    local north_arrow = this.turn == 'north' and Icons.left_arrow_enabled or Icons.left_arrow_disabled
    local south_arrow = this.turn == 'south' and Icons.right_arrow_enabled or Icons.right_arrow_disabled
    local north_players = Public.get_force_tooltip(this.north.list, 'north')
    local south_players = Public.get_force_tooltip(this.south.list, 'south')

    for _, player in pairs(game.connected_players) do
        local frame = Public.draw(player)
        local data = Gui.get_data(frame)

        data.timer_info.tooltip = timer_info

        -- North
        data.north_time.caption = north_time
        data.north_picks.caption = north_arrow
        data.north_picks.tooltip = north_picks
        data.north_team.tooltip = north_players

        -- South
        data.south_time.caption = south_time
        data.south_picks.caption = south_arrow
        data.south_picks.tooltip = south_picks
        data.south_team.tooltip = south_players
    end
end

Public.on_tick_token = Token.register(on_tick)

-- == GUI =====================================================================

---@param player LuaPlayer
Public.draw = function(player)
    if not (player and player.valid) then
        return
    end

    local frame = player.gui.screen[main_frame_name]
    if frame and frame.valid then
        return frame
    end

    local show_info = {}
    local show_filter = {}
    local data = {
        frame = nil,
        columns = nil,
        body = nil,
        row_1 = nil,
        row_2 = nil,
        scroll_pane = nil,
        refresh = nil,
        searchbox = nil,
        show_info = show_info,
        show_filter = show_filter,
        timer_info = nil,
        north_time = '',
        south_time = '',
    }

    frame = player.gui.screen.add({ type = 'frame', name = main_frame_name, direction = 'horizontal' })
    Gui.set_style(frame, { horizontally_stretchable = true, top_padding = 8, bottom_padding = 8 })
    Gui.set_data(frame, data)
    data.frame = frame

    favourites[player.index] = favourites[player.index] or {}
    local preferences = Public.get_player_preferences(player.index)

    local columns = {
        frame.add({ type = 'flow', direction = 'vertical' }),
        frame.add({ type = 'flow', direction = 'vertical' }),
    }
    data.columns = columns
    columns[2].visible = preferences.view_settings

    for _, c in pairs(columns) do
        Gui.set_style(c, { vertically_stretchable = false })
    end

    do --- Title
        local flow = columns[1].add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(flow, { horizontal_spacing = 8, vertical_align = 'center', bottom_padding = 4 })

        local minimize = flow.add({
            type = 'sprite-button',
            name = minimize_button_name,
            style = 'frame_action_button',
            sprite = 'utility/track_button_white',
            auto_toggle = true,
            tooltip = 'Toggle to minimize/maximize window',
        })
        Gui.set_style(minimize, { padding = 1 })
        Gui.set_data(minimize, data)

        local dragger = flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
        dragger.drag_target = frame
        Gui.set_style(dragger, { height = 24, minimal_width = 48, horizontally_stretchable = true })

        local label = flow.add({
            type = 'label',
            caption = 'Team picker',
            style = 'frame_title',
            tooltip = { 'captain.team_picker_tooltip' },
        })
        label.drag_target = frame

        local label = flow.add({ type = 'label', caption = '[img=info]', tooltip = { 'captain.team_picker_tooltip' } })
        label.drag_target = frame

        local dragger = flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
        dragger.drag_target = frame
        Gui.set_style(dragger, { height = 24, minimal_width = 48, horizontally_stretchable = true })

        local settings_button = flow.add({
            type = 'button',
            name = settings_button_name,
            style = 'frame_button',
            caption = 'Settings',
            tooltip = 'Referee settings',
        })
        Gui.set_style(settings_button, {
            font_color = { 230, 230, 230 },
            height = 24,
            width = 80,
            natural_width = 80,
            font = 'heading-2',
            left_padding = 8,
            right_padding = 8,
        })
        Gui.set_data(settings_button, data)
    end

    local column_1 = columns[1].add({ type = 'frame', style = 'inside_deep_frame', direction = 'vertical' })
    Gui.set_style(column_1, {
        horizontally_stretchable = true,
        natural_width = 860,
        natural_height = 750,
        maximal_height = 900,
    })
    data.body = column_1

    --- Header
    local header = column_1.add({ type = 'frame', style = 'subheader_frame', direction = 'vertical' })
    Gui.set_style(header, { natural_height = 36, maximal_height = 200, bottom_padding = 3, top_padding = 3 })

    do -- 1st row
        local row_1 = header.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(row_1, { vertical_align = 'center', top_margin = 3 })
        data.row_1 = row_1

        row_1.add({
            type = 'label',
            caption = 'Sort by',
            style = 'subheader_semibold_label',
            tooltip = { 'captain.sort_by_tooltip' },
        })

        local dropdown = row_1.add({
            type = 'drop-down',
            items = DEFAULT.sorting,
            name = action_sort_by,
            selected_index = table.index_of(DEFAULT.sorting, preferences.sorting),
        })
        Gui.set_style(dropdown, { height = 26 })

        Gui.add_pusher(row_1)

        row_1.add({ type = 'line', direction = 'vertical' })

        Gui.add_pusher(row_1)

        row_1.add({
            type = 'label',
            caption = 'Show',
            style = 'subheader_semibold_label',
            tooltip = { 'captain.show_category_tooltip' },
        })
        local show_flow = row_1.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(show_flow, { horizontal_spacing = 0 })

        for _, button in pairs({
            show_flow.add({
                type = 'button',
                auto_toggle = true,
                caption = 'Playtime',
                tags = { [Gui.tag] = action_show_info, type = 'playtime' },
                toggled = preferences.playtime,
            }),
            show_flow.add({
                type = 'button',
                auto_toggle = true,
                caption = 'Value',
                tags = { [Gui.tag] = action_show_info, type = 'value' },
                toggled = preferences.value,
                tooltip = { 'captain.expand_filters_tooltip' },
            }),
            show_flow.add({
                type = 'button',
                auto_toggle = true,
                caption = 'Tasks',
                tags = { [Gui.tag] = action_show_info, type = 'tasks' },
                toggled = preferences.tasks,
                tooltip = { 'captain.expand_filters_tooltip' },
            }),
            show_flow.add({
                type = 'button',
                auto_toggle = true,
                caption = 'Notes',
                tags = { [Gui.tag] = action_show_info, type = 'notes' },
                toggled = preferences.notes,
            }),
        }) do
            Gui.set_style(
                button,
                { height = 26, left_padding = 12, right_padding = 12, minimal_width = 85, minimal_height = 0 }
            )
            Gui.set_data(button, data)
            show_info[button.tags.type] = {}
        end

        Gui.add_pusher(row_1)

        row_1.add({ type = 'line', direction = 'vertical' })

        Gui.add_pusher(row_1)

        local label = row_1.add({
            type = 'label',
            caption = '[img=utility/search]',
            style = 'subheader_semibold_label',
            tooltip = 'Search player name/cmments',
        })
        local searchbox = row_1.add({ type = 'textfield', name = searchbox_name, style = 'search_popup_textfield' })
        Gui.set_style(searchbox, { maximal_height = 26 })
        data.searchbox = searchbox
    end
    do -- 2nd row
        local row_2 = header.add({ type = 'flow', direction = 'horizontal' })
        row_2.visible = false
        show_filter.value = row_2

        local value_info = row_2.add({ type = 'frame', style = 'bordered_frame' })
        Gui.set_style(value_info, { bottom_padding = 0 })

        value_info.add({
            type = 'label',
            caption = 'Player value',
            style = 'subheader_semibold_label',
            tooltip = { 'captain.sort_by_tasks_tooltip' },
        })

        Gui.add_pusher(value_info)

        local label = value_info.add({ type = 'label', caption = { 'captain.player_value_caption' } })
        Gui.set_style(label, { minimal_width = 300, single_line = false })
    end
    do -- 3rd row
        local row_3 = header.add({ type = 'flow', direction = 'horizontal' })
        row_3.visible = false
        show_filter.tasks = row_3

        local tasks_frame = row_3.add({ type = 'frame', style = 'bordered_frame' })
        Gui.set_style(tasks_frame, { bottom_padding = 0 })

        local tasks_flow = tasks_frame.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(tasks_flow, { vertical_align = 'center' })

        tasks_flow.add({
            type = 'label',
            caption = 'Sort by tasks',
            style = 'subheader_semibold_label',
            tooltip = { 'captain.sort_by_tasks_tooltip' },
        })
        Gui.add_pusher(tasks_flow)

        local tasks = tasks_flow.add({ type = 'table', column_count = #DEFAULT.tasks })
        for _, task_name in pairs(DEFAULT.tasks) do
            local button = tasks.add({
                type = 'sprite-button',
                sprite = 'item/' .. task_name,
                style = 'slot_button', --p.tasks[task_name] and 'item_and_count_select_confirm' or
                tooltip = { 'enrollment_tasks.' .. task_name },
                tags = { [Gui.tag] = action_toggle_task_filter, task_name = task_name },
                auto_toggle = true,
                toggled = preferences.filter_by_task[task_name] ~= nil,
            })
            Gui.set_style(button, { size = 32 })
        end

        tasks_flow.add({ type = 'line', direction = 'vertical' })
        local reset_button = tasks_flow.add({
            type = 'sprite-button',
            style = 'slot_button',
            sprite = 'utility/reset_white',
            tooltip = 'Clear all',
            name = action_reset_task_filter,
        })
        Gui.set_style(reset_button, { size = 32, padding = 4 })
        Gui.set_data(reset_button, tasks)
    end

    do --- List
        local scroll_pane = column_1.add({ type = 'scroll-pane', style = 'text_holding_scroll_pane' })
        Gui.set_style(scroll_pane, {
            vertically_stretchable = true,
            vertically_squashable = false,
            maximal_height = 860,
            minimal_width = 975,
            --minimal_height = 200,
        })
        scroll_pane.vertical_scroll_policy = 'always'
        scroll_pane.horizontal_scroll_policy = 'auto-and-reserve-space'
        data.scroll_pane = scroll_pane
    end

    do --- Subfooter
        local subfooter =
            column_1.add({ type = 'frame', style = 'subfooter_frame' }).add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(subfooter, {
            horizontally_stretchable = true,
            horizontal_align = 'right',
            vertical_align = 'center',
            right_padding = 10,
        })

        Gui.add_pusher(subfooter)

        local north = subfooter.add({ type = 'label', style = 'caption_label', caption = 'North' })
        Gui.set_style(north, { font_color = { 140, 140, 252 } })
        data.north_team = north

        local t1 = subfooter.add({ type = 'label', style = 'caption_label', caption = '04:09' })
        Gui.set_style(t1, { padding = 12, font = 'default-large', font_color = { 255, 255, 255 } })
        data.north_time = t1

        local p1 = subfooter.add({ type = 'label', caption = '---' })
        Gui.set_style(p1, { right_padding = 6, font = 'default-small' })
        data.north_picks = p1

        local timer_info = subfooter.add({
            type = 'label',
            style = 'caption_label',
            caption = '[img=virtual-signal/signal-hourglass]',
            tooltip = '---',
        })
        data.timer_info = timer_info

        local p2 = subfooter.add({ type = 'label', caption = '---' })
        Gui.set_style(p2, { left_padding = 6, font = 'default-small' })
        data.south_picks = p2

        local t2 = subfooter.add({ type = 'label', style = 'caption_label', caption = '02:45' })
        Gui.set_style(t2, { padding = 12, font = 'default-large', font_color = { 255, 255, 255 } })
        data.south_time = t2

        local south = subfooter.add({ type = 'label', style = 'caption_label', caption = 'South' })
        Gui.set_style(south, { font_color = { 252, 084, 084 } })
        data.south_team = south

        Gui.add_pusher(subfooter)

        local refresh = subfooter.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(refresh, { vertical_align = 'center' })
        data.refresh = refresh

        refresh.add({ type = 'label', caption = 'Refresh ', style = 'caption_label' })
        local refresh_button = refresh.add({
            type = 'sprite-button',
            name = action_refresh_list,
            sprite = 'utility/refresh',
            style = 'tool_button',
            tooltip = 'Refresh the player list',
        })
        Gui.set_data(refresh_button, data)
    end

    Public.update(player)
    if preferences.view_settings then
        Public.draw_settings(player)
    end

    frame.auto_center = true
    return frame
end

---@param player LuaPlayer
Public.update = function(player)
    local data = Gui.get_data(player.gui.screen[main_frame_name])
    if not data then
        return
    end

    local scroll_pane = data.scroll_pane
    Gui.clear(scroll_pane)

    local show_info = { playtime = {}, value = {}, tasks = {}, notes = {} }
    data.show_info = show_info

    local preferences = Public.get_player_preferences(player.index)

    local function add_player(parent, p)
        local player_frame = parent.add({ type = 'frame', direction = 'vertical' })
        Gui.set_style(player_frame, { horizontally_stretchable = true, bottom_padding = 0, top_padding = 0 })

        local row = player_frame.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(row, {
            horizontal_spacing = 10,
            vertical_align = 'center',
            natural_height = 32,
            maximal_width = 940,
            top_padding = 1,
        })

        local favourite = row.add({
            type = 'label',
            name = action_mark_favourite,
            caption = favourites[player.index][p.index] and Icons.favourite_enabled or Icons.favourite_disabled,
            tooltip = favourites[player.index][p.index] and 'Remove from favourites' or 'Add to favourites',
            tags = { player_index = p.index },
        })
        Gui.set_style(favourite, { font = 'default-small' })

        local name = row.add({
            type = 'button',
            name = action_pick_player,
            caption = p.name,
            style = 'frame_action_button',
            tooltip = 'Pick ' .. p.name,
            tags = { player_index = p.index },
        })
        Gui.set_style(name, { font_color = p.player.color, width = 150, height = 26, margin = 0 })

        local playtime = row.add({ type = 'label', caption = Public.format_time(p.playtime) })
        Gui.set_style(playtime, { minimal_width = 50 })
        table_insert(show_info.playtime, playtime)
        playtime.visible = preferences.playtime

        local info_value = row.add({ type = 'flow', direction = 'horizontal' })
        Gui.set_style(info_value, { horizontal_spacing = 10, vertical_align = 'center' })

        local value = info_value.add({
            type = 'sprite-button',
            sprite = 'item/coin',
            style = 'transparent_slot',
            number = p.value,
            tooltip = p.value_tooltip,
        })
        Gui.set_style(value, { padding = 4 })
        local downvote = info_value.add({
            type = 'label',
            style = 'heading_2_label',
            caption = '[img=virtual-signal/down-arrow;tint=255,0,0]',
            tooltip = 'Downvote',
            tags = { [Gui.tag] = action_cast_vote, value = -1, player_index = p.index },
        })
        local upvote = info_value.add({
            type = 'label',
            style = 'heading_2_label',
            caption = '[img=virtual-signal/up-arrow;tint=0,255,0]',
            tooltip = 'Upvote',
            tags = { [Gui.tag] = action_cast_vote, value = 1, player_index = p.index },
        })
        table_insert(show_info.value, info_value)
        info_value.visible = preferences.value

        local info_tasks = row.add({ type = 'frame', style = 'inside_deep_frame' })

        local tasks = info_tasks.add({ type = 'table', column_count = #DEFAULT.tasks })
        Gui.set_style(tasks, { minimal_width = 28, horizontal_spacing = 0 })

        for _, task_name in pairs(DEFAULT.tasks) do
            local button = tasks.add({
                type = 'sprite-button',
                sprite = 'item/' .. task_name,
                style = p.tasks[task_name] and 'item_and_count_select_confirm' or 'slot_button',
                tooltip = { 'enrollment_tasks.' .. task_name },
            })
            Gui.set_style(button, { size = 28 })
        end
        table_insert(show_info.tasks, info_tasks)
        info_tasks.visible = preferences.tasks

        local note = row.add({
            type = 'label',
            caption = p.note,
        })
        Gui.set_style(note, { minimal_width = 100, single_line = false })
        table_insert(show_info.notes, note)
        note.visible = preferences.notes
    end

    for _, params in pairs(Public.get_sorted_list(player)) do
        if params.player.force.name == 'spectator' then
            add_player(scroll_pane, params)
        end
    end
end

--- Use Public.queue_update()
Public.update_all = function()
    for _, player in pairs(game.connected_players) do
        Public.update(player)
    end
end

Public.draw_all = function()
    for _, player in pairs(game.connected_players) do
        Public.draw(player)
    end
end

---@param player LuaPlayer
Public.destroy = function(player)
    if not (player and player.valid) then
        return
    end

    local frame = player.gui.screen[main_frame_name]
    if frame then
        Gui.destroy(frame)
    end
end

Public.destroy_all = function()
    for _, player in pairs(game.players) do
        Public.destroy(player)
    end
end

---@param player LuaPlayer
Public.draw_settings = function(player)
    if not (player and player.valid) then
        return
    end

    local frame = player.gui.screen[main_frame_name]
    if not (frame and frame.valid) then
        return
    end
    local column = Gui.get_data(frame).columns[2]
    column.visible = true
    if #column.children > 0 then
        return column
    end

    local parent = column.add({ type = 'frame', style = 'inside_shallow_frame_with_padding', direction = 'vertical' })
    Gui.set_style(parent, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        minimal_width = 200,
        left_margin = 6,
    })

    local box_1 = parent
        .add({ type = 'frame', style = 'bordered_frame', direction = 'vertical', caption = 'Player picker settings' })
        .add({ type = 'table', column_count = 2 })
    for i, button in pairs({
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = '+1 North',
            tags = { [Gui.tag] = draft_timer_favor, side = 'north', delta = 1 },
        }),
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = '+1 South',
            tags = { [Gui.tag] = draft_timer_favor, side = 'south', delta = 1 },
        }),
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = 'Favor North',
            tags = { [Gui.tag] = draft_timer_favor, side = 'north' },
        }),
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = 'Favor South',
            tags = { [Gui.tag] = draft_timer_favor, side = 'south' },
        }),
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = '-1 North',
            tags = { [Gui.tag] = draft_timer_favor, side = 'north', delta = -1 },
        }),
        box_1.add({
            type = 'button',
            style = 'frame_button',
            caption = '-1 South',
            tags = { [Gui.tag] = draft_timer_favor, side = 'south', delta = -1 },
        }),
    }) do
        Gui.set_style(button, {
            maximal_height = 28,
            minimal_width = 115,
            font_color = (i % 2 == 1) and { 140, 140, 252 } or { 252, 084, 084 },
        })
    end

    local box_2 = parent
        .add({ type = 'frame', style = 'bordered_frame', direction = 'horizontal', caption = 'Draft Timer settings' })
        .add({ type = 'table', column_count = 2 })
    for i, button in pairs({
        box_2.add({
            type = 'button',
            style = 'red_back_button',
            name = draft_timer_disable,
            caption = 'Disable',
            tooltip = 'Cancel captain game',
        }),
        box_2.add({
            type = 'button',
            style = 'confirm_button_without_tooltip',
            name = draft_timer_enable,
            caption = 'Enable',
        }),
        box_2.add({ type = 'button', style = 'red_back_button', name = draft_timer_unpause, caption = 'Unpause' }),
        box_2.add({
            type = 'button',
            style = 'confirm_button_without_tooltip',
            name = draft_timer_pause,
            caption = 'Pause',
        }),
        box_2.add({
            type = 'button',
            style = 'red_back_button',
            caption = 'Remove 0:30',
            tags = { [Gui.tag] = draft_timer_change, time = -30 * 60 },
        }),
        box_2.add({
            type = 'button',
            style = 'confirm_button_without_tooltip',
            caption = 'Add 0:30',
            tags = { [Gui.tag] = draft_timer_change, time = 30 * 60 },
        }),
        box_2.add({
            type = 'button',
            style = 'red_back_button',
            caption = 'Remove 5:00',
            tags = { [Gui.tag] = draft_timer_change, time = -5 * 60 * 60 },
        }),
        box_2.add({
            type = 'button',
            style = 'confirm_button_without_tooltip',
            caption = 'Add 5:00',
            tags = { [Gui.tag] = draft_timer_change, time = 5 * 60 * 60 },
        }),
    }) do
        Gui.set_style(
            button,
            { maximal_height = 28, minimal_width = 115, font = 'default-semibold', font_color = { 0, 0, 0 } }
        )
    end
end

---@param parent LuaGuiElement
Public.draw_enrollment_tasks = function(parent)
    local p = this.spectator.list[parent.player_index]
    local flow = parent[enrollment_flow_name]

    if not p then
        if flow then
            Gui.destroy(flow)
        end
        return
    end

    local tasks
    if not flow then
        flow = parent.add({ type = 'flow', name = enrollment_flow_name, direction = 'horizontal' })
        Gui.set_style(flow, { horizontal_align = 'center', margin = 8 })

        Gui.add_pusher(flow)

        tasks = flow.add({ type = 'frame', style = 'inside_deep_frame' })
            .add({ type = 'table', column_count = #DEFAULT.tasks })
        Gui.set_style(tasks, { horizontal_spacing = 0 })

        Gui.add_pusher(flow)
    else
        tasks = flow.children[2].children[1]
    end

    tasks.clear()

    for _, task_name in pairs(DEFAULT.tasks) do
        local button = tasks.add({
            type = 'sprite-button',
            sprite = 'item/' .. task_name,
            style = p.tasks[task_name] and 'item_and_count_select_confirm' or 'slot_button',
            tooltip = { 'enrollment_tasks.' .. task_name },
            tags = { [Gui.tag] = action_toggle_task, task_name = task_name },
        })
        Gui.set_data(button, parent)
        Gui.set_style(button, { size = 40 })
    end
end

-- == EVENTS ==================================================================

Gui.on_click(minimize_button_name, function(event)
    if Public.debounce(event.player) then
        return
    end

    local element = event.element
    local data = Gui.get_data(element)

    data.row_1.parent.visible = not element.toggled
    data.scroll_pane.visible = not element.toggled
    data.refresh.visible = not element.toggled
    if element.toggled then
        Gui.set_style(data.body, {
            natural_width = 0,
            natural_height = 0,
        })
    else
        Gui.set_style(data.body, {
            natural_width = 860,
            natural_height = 750,
        })
    end
end)

Gui.on_click(settings_button_name, function(event)
    if not CaptainUtils.is_player_the_referee(event.player.name) then
        return
    end

    local preferences = Public.get_player_preferences(event.player_index)
    preferences.view_settings = not preferences.view_settings

    if preferences.view_settings then
        Public.draw_settings(event.player)
    else
        local data = Gui.get_data(event.element)
        data.columns[2].visible = false
    end
end)

Gui.on_click(action_toggle_task, function(event)
    if Public.debounce(event.player) then
        return
    end

    Public.toggle_enrollment_task(event.player_index, event.element.tags.task_name)
    Public.draw_enrollment_tasks(Gui.get_data(event.element))
end)

Gui.on_click(action_toggle_task_filter, function(event)
    if Public.debounce(event.player) then
        return
    end

    local task_name = event.element.tags.task_name
    local list = Public.get_player_preferences(event.player_index).filter_by_task
    if not list then
        return
    end

    if list[task_name] then
        list[task_name] = nil
    else
        list[task_name] = true
    end

    Public.update(event.player)
end)

Gui.on_click(action_reset_task_filter, function(event)
    if Public.debounce(event.player) then
        return
    end

    local tasks = Gui.get_data(event.element)
    for _, button in pairs(tasks.children) do
        button.toggled = false
    end

    table.clear_table(Public.get_player_preferences(event.player_index).filter_by_task)
    Public.update(event.player)
end)

Gui.on_click(action_cast_vote, function(event)
    event.player.play_sound({ path = 'utility/gui_click' })

    if Public.debounce(event.player) then
        return
    end

    Public.cast_vote(event.player_index, event.element.tags.player_index, event.element.tags.value)
    Public.queue_update()
end)

Gui.on_click(action_mark_favourite, function(event)
    event.player.play_sound({ path = 'utility/gui_click' })

    if Public.debounce(event.player) then
        return
    end

    local viewer_index = event.element.player_index
    local target_index = event.element.tags.player_index
    if favourites[viewer_index][target_index] then
        favourites[viewer_index][target_index] = nil
    else
        favourites[viewer_index][target_index] = true
    end

    event.element.caption = favourites[viewer_index][target_index] and Icons.favourite_enabled
        or Icons.favourite_disabled
    event.element.tooltip = favourites[viewer_index][target_index] and 'Remove from favourites' or 'Add to favourites'
end)

Gui.on_click(action_pick_player, function(event)
    if Public.debounce(event.player) then
        return
    end
    if not CaptainUtils.is_player_a_captain(event.player.name) then
        return
    end
    if event.player.force.name ~= this.turn then
        return
    end

    Public.pick_player(event.element.tags.player_index)

    local side = this[this.turn]
    side.picked = side.picked + 1
    if side.picked >= side.picks then
        Public.switch_turn()
    end

    Public.queue_update()
end)

Gui.on_click(action_refresh_list, function(event)
    if Public.debounce(event.player) then
        return
    end

    local data = Gui.get_data(event.element)
    data.searchbox.text = ''

    Public.get_player_preferences(event.player_index).filter = nil
    Public.update(event.player)
end)

Gui.on_click(action_show_info, function(event)
    if Public.debounce(event.player) then
        return
    end

    local element = event.element
    local category = element.tags.type

    if event.button == defines.mouse_button_type.left then
        Public.get_player_preferences(event.player_index)[category] = element.toggled

        for _, child in pairs(Gui.get_data(element).show_info[category]) do
            child.visible = element.toggled
        end
    elseif event.button == defines.mouse_button_type.right then
        element.toggled = not element.toggled
        local filters = Gui.get_data(element).show_filter
        if filters[category] then
            filters[category].visible = not filters[category].visible
        end
    end
end)

Gui.on_text_changed(searchbox_name, function(event)
    local text = event.text
    Public.get_player_preferences(event.player_index).filter = (text == '' and nil) or text
    Public.update(event.player)
end)

Gui.on_selection_state_changed(action_sort_by, function(event)
    local preferences = Public.get_player_preferences(event.player_index)
    preferences.sorting = DEFAULT.sorting[event.element.selected_index]
    Public.update(event.player)
end)

Gui.on_click(draft_timer_favor, function(event)
    local side = event.element.tags.side
    local delta = event.element.tags.delta

    if delta then
        this[side].picks = this[side].picks + delta
    else
        Public.switch_turn(side)
    end
end)

Gui.on_click(draft_timer_enable, Public.enable)

Gui.on_click(draft_timer_disable, function(event)
    Public.disable()
    Public.force_end_captain_event()
end)

Gui.on_click(draft_timer_pause, Public.pause)

Gui.on_click(draft_timer_unpause, Public.unpause)

Gui.on_click(draft_timer_change, function(event)
    Public.change_time(event.element.tags.time)
end)

-- == UTILS ===================================================================

---@param strings string[]
---@param pattern string
local function match_str(strings, pattern)
    if not pattern then
        return true
    end

    pattern = pattern:lower()
    for _, str in pairs(strings) do
        if string_find(str:lower(), pattern) then
            return true
        end
    end

    return false
end

---@param reference table<string, boolean>
---@param object table<string, boolean>
local function match_dict(reference, object)
    for k, v in pairs(reference) do
        if v and not object[k] then
            return false
        end
    end

    return true
end

Public.queue_update = function()
    this.next_update = game.tick + 1
end

---@param player LuaPlayer
Public.debounce = function(player)
    if game.tick_paused then
        return true
    end

    local tick = debounce[player.index]
    if tick and tick >= game.tick then
        player.print({ 'gui.debounce' })
        return true
    end

    debounce[player.index] = game.tick + 10 -- 166ms
    return false
end

---@param ticks number
Public.format_time_short = function(ticks)
    local seconds = math_floor(ticks / 60)
    local minutes = math_floor(seconds / 60)

    seconds = seconds % 60

    return string_format('%02d:%02d', minutes, seconds)
end

---@param ticks number
Public.format_time = function(ticks)
    local seconds = math_floor(ticks / 60)
    local minutes = math_floor(seconds / 60)
    local hours = math_floor(minutes / 60)
    local days = math_floor(hours / 24)

    minutes = minutes % 60
    hours = hours % 24

    return string_format(
        '[font=default-semibold]%02d[/font][font=default-small]d[/font] [font=default-semibold]%02d[/font][font=default-small]h[/font] [font=default-semibold]%02d[/font][font=default-small]m[/font]',
        days,
        hours,
        minutes
    )
end

---@param list table<integer, PlayerMeta>
Public.get_force_settings = function(list)
    return {
        ---@type PlayerMeta[]
        list = list or {},
        time = 0,
        picks = 0,
        rounds = 0,
        picked = 0,
    }
end

---@param player_index integer
Public.get_player_preferences = function(player_index)
    local preferences = player_preferences[player_index]
    if not preferences then
        preferences = {
            playtime = true,
            value = true,
            tasks = false,
            notes = true,
            sorting = 'Playtime',
            filter = nil,
            view_settings = false,
            filter_by_task = {},
        }
        player_preferences[player_index] = preferences
    end
    return preferences
end

---@param player_index integer
Public.get_favourites_list = function(player_index)
    local result = {}

    for k, _ in pairs(favourites[player_index] or {}) do
        table_insert(result, k)
    end

    return result
end

---@param player LuaPlayer
Public.get_sorted_list = function(player)
    local top = {}
    local middle = {}
    local bottom = {}
    local preferences = Public.get_player_preferences(player.index)
    local marked = favourites[player.index]
    local filter = preferences.filter
    local reference_list = this[player.force.name] and this[player.force.name].list or this.spectator.list

    filter = filter and filter:lower()

    for _, p in pairs(reference_list) do
        local tasks = table_concat(table.keys(p.tasks), '')
        if match_str({ p.name, p.note, tasks }, filter) then
            if match_dict(preferences.filter_by_task, p.tasks) then
                table_insert(marked[p.index] and top or middle, p)
            else
                table_insert(bottom, p)
            end
        end
    end

    table_sort(top, Comparators[preferences.sorting])
    table_sort(middle, Comparators[preferences.sorting])
    table_sort(bottom, Comparators[preferences.sorting])

    table_add_all(top, middle)
    table_add_all(top, bottom)

    return top
end

---@param playerMeta PlayerMeta
Public.get_value_tooltip = function(playerMeta)
    local votes = {}

    for actor_index, value in pairs(playerMeta.votes) do
        local sign = value > 0 and '+' or '-'
        local color = value > 0 and 'green' or 'red'
        local actor = Public.get_player(actor_index)
        local _c = actor.player.color
        local actor_color = string_format('%.2f,%.2f,%.2f', _c.r, _c.g, _c.b)
        table_insert(
            votes,
            string_format(
                '[font=default-listbox][color=%s]%s%04d[/color] - [color=%s]%s[/color][/font]',
                color,
                sign,
                math.abs(value),
                actor_color,
                actor.name
            )
        )
    end

    table_sort(votes)
    return table_concat(votes, '\n')
end

---@param list table<integer, PlayerMeta>
---@param force LuaForce
Public.get_force_tooltip = function(list, force)
    local tmp, result = {}, {}

    for _, p in pairs(list) do
        if p.player.force.name == force then
            table_insert(tmp, p)
        end
    end

    table_sort(tmp, Comparators.Rank)

    for _, p in pairs(tmp) do
        local _c = p.player.color
        local color = string_format('%.2f,%.2f,%.2f', _c.r, _c.g, _c.b)
        table_insert(
            result,
            string_format('[font=default-listbox]%02d - [color=%s]%s[/color][/font]', p.rank, color, p.name)
        )
    end

    return table_concat(result, '\n')
end

-- ============================================================================

return Public
