-- config tab --

local Antigrief = require 'antigrief'
local Color = require 'utils.color_presets'
local SessionData = require 'utils.datastore.session_data'
local Utils = require 'utils.core'
local Gui = require 'utils.gui'
local gui_themes = require 'utils.utils'.gui_themes
local index_of = table.index_of

local spaghett_entity_blacklist = {
    ['logistic-chest-requester'] = true,
    ['logistic-chest-buffer'] = true,
    ['logistic-chest-active-provider'] = true
}

local function get_actor(event, prefix, msg, admins_only)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    if admins_only then
        Utils.print_admins(msg, player.name)
    else
        Utils.action_warning(prefix, player.name .. ' ' .. msg)
    end
end

local function spaghett_deny_building(event)
    local spaghett = global.comfy_panel_config.spaghett
    if not spaghett.enabled then
        return
    end
    local entity = event.created_entity
    if not entity.valid then
        return
    end
    if not spaghett_entity_blacklist[event.created_entity.name] then
        return
    end

    if event.player_index then
        game.get_player(event.player_index).insert({name = entity.name, count = 1})
    else
        local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        inventory.insert({name = entity.name, count = 1})
    end

    event.created_entity.surface.create_entity(
        {
            name = 'flying-text',
            position = entity.position,
            text = 'Spaghett Mode Active!',
            color = {r = 0.98, g = 0.66, b = 0.22}
        }
    )

    entity.destroy()
end

local function spaghett()
    local spaghett = global.comfy_panel_config.spaghett
    if spaghett.enabled then
        for _, f in pairs(game.forces) do
            if f.technologies['logistic-system'].researched then
                spaghett.undo[f.index] = true
            end
            f.technologies['logistic-system'].enabled = false
            f.technologies['logistic-system'].researched = false
        end
    else
        for _, f in pairs(game.forces) do
            f.technologies['logistic-system'].enabled = true
            if spaghett.undo[f.index] then
                f.technologies['logistic-system'].researched = true
                spaghett.undo[f.index] = nil
            end
        end
    end
end

local function trust_connected_players()
    local trust = SessionData.get_trusted_table()
    local AG = Antigrief.get()
    local players = game.connected_players
    if not AG.enabled then
        for _, p in pairs(players) do
            trust[p.name] = true
        end
    else
        for _, p in pairs(players) do
            trust[p.name] = false
        end
    end
end

local function theme_names()
    local keys, values = {}, {}
    for _, v in pairs(gui_themes) do
        keys[#keys + 1] = v.type
        values[#values + 1] = v.name
    end
    return { keys = keys, values = values }
end
local themes = theme_names()

local functions = {
    ['comfy_panel_spectator_switch'] = function(event)
        if event.element.switch_state == 'left' then
            game.get_player(event.player_index).spectator = true
        else
            game.get_player(event.player_index).spectator = false
        end
    end,
    ['comfy_panel_want_pings_switch'] = function(event)
        local player = game.get_player(event.player_index)
        if not player then return end
        if event.element.switch_state == 'left' then
            global.want_pings[player.name] = true
        else
            global.want_pings[player.name] = false
            global.ping_gui_locations[player.name] = nil
        end
    end,
    ['comfy_panel_auto_hotbar_switch'] = function(event)
        if event.element.switch_state == 'left' then
            global.auto_hotbar_enabled[event.player_index] = true
        else
            global.auto_hotbar_enabled[event.player_index] = false
        end
    end,
    ['comfy_panel_blueprint_toggle'] = function(event)
        if event.element.switch_state == 'left' then
            game.permissions.get_group('Default').set_allows_action(
                defines.input_action.open_blueprint_library_gui,
                true
            )
            game.permissions.get_group('Default').set_allows_action(defines.input_action.import_blueprint_string, true)
            get_actor(event, '{Blueprints}', 'has enabled blueprints!')
        else
            game.permissions.get_group('Default').set_allows_action(
                defines.input_action.open_blueprint_library_gui,
                false
            )
            game.permissions.get_group('Default').set_allows_action(defines.input_action.import_blueprint_string, false)
            get_actor(event, '{Blueprints}', 'has disabled blueprints!')
        end
    end,
    ['comfy_panel_spaghett_toggle'] = function(event)
        if event.element.switch_state == 'left' then
            global.comfy_panel_config.spaghett.enabled = true
            get_actor(event, '{Spaghett}', 'has enabled spaghett mode!')
        else
            global.comfy_panel_config.spaghett.enabled = nil
            get_actor(event, '{Spaghett}', 'has disabled spaghett mode!')
        end
        spaghett()
    end,
	["bb_team_balancing_toggle"] = function(event) 
		if event.element.switch_state == "left" then
			global.bb_settings.team_balancing = true
			game.print("Team balancing has been enabled!")
		else
			global.bb_settings.team_balancing = false
			game.print("Team balancing has been disabled!")
		end
	end,
	
	["bb_only_admins_vote"] = function(event) 
		if event.element.switch_state == "left" then
			global.bb_settings.only_admins_vote = true
			global.difficulty_player_votes = {}
			game.print("Admin-only difficulty voting has been enabled!")
		else
			global.bb_settings.only_admins_vote = false
			game.print("Admin-only difficulty voting has been disabled!")
		end
	end,
	["comfy_panel_new_year_island"] = function(event)
		if event.element.switch_state == "left" then
			global.bb_settings['new_year_island'] = true
            get_actor(event, '{New Year Island}', "New Year island has been enabled!", true)
		else
			global.bb_settings['new_year_island'] = false
			get_actor(event, '{New Year Island}', "New Year island has been disabled!", true)
		end
	end,

	["bb_map_reveal_toggle"] = function(event)
		if event.element.switch_state == "left" then
			global.bb_settings['bb_map_reveal_toggle'] = true
			game.print("Reveal map at start has been enabled!")
		else
			global.bb_settings['bb_map_reveal_toggle'] = false
			game.print("Reveal map at start has been disabled!")
		end
	end,

	["bb_map_reroll_toggle"] = function(event)
		if event.element.switch_state == "left" then
			global.bb_settings.map_reroll = true
			game.print("Map Reroll is enabled!")
		else
			global.bb_settings.map_reroll = false
			game.print("Map Reroll is disabled!")
		end
	end,
    ["bb_burners_balance_toggle"] = function(event)
		if event.element.switch_state == "left" then
			global.bb_settings.burners_balance = true
			game.print("Burners balance is enabled!")
		else
			global.bb_settings.burners_balance = false
			game.print("Burners balance is disabled!")
		end
	end,
}

local poll_function = {
    ['comfy_panel_poll_trusted_toggle'] = function(event)
        if event.element.switch_state == 'left' then
            global.comfy_panel_config.poll_trusted = true
            get_actor(event, '{Poll Mode}', 'has disabled non-trusted people to do polls.')
        else
            global.comfy_panel_config.poll_trusted = false
            get_actor(event, '{Poll Mode}', 'has allowed non-trusted people to do polls.')
        end
    end,
    ['comfy_panel_poll_no_notify_toggle'] = function(event)
        local poll = package.loaded['comfy_panel.poll']
        local poll_table = poll.get_no_notify_players()
        if event.element.switch_state == 'left' then
            poll_table[event.player_index] = false
        else
            poll_table[event.player_index] = true
        end
    end
}

local antigrief_functions = {
    ['comfy_panel_disable_antigrief'] = function(event)
        local AG = Antigrief.get()
        if event.element.switch_state == 'left' then
            AG.enabled = true
            get_actor(event, '{Antigrief}', 'has enabled the antigrief function.', true)
        else
            AG.enabled = false
            get_actor(event, '{Antigrief}', 'has disabled the antigrief function.', true)
        end
        trust_connected_players()
    end
}

local fortress_functions = {
    ['comfy_panel_disable_fullness'] = function(event)
        local Fullness = package.loaded['modules.check_fullness']
        local this = Fullness.get()
        if event.element.switch_state == 'left' then
            this.fullness_enabled = true
            get_actor(event, '{Fullness}', 'has enabled the inventory fullness function.')
        else
            this.fullness_enabled = false
            get_actor(event, '{Fullness}', 'has disabled the inventory fullness function.')
        end
    end,
    ['comfy_panel_offline_players'] = function(event)
        local WPT = package.loaded['maps.mountain_fortress_v3.table']
        local this = WPT.get()
        if event.element.switch_state == 'left' then
            this.offline_players_enabled = true
            get_actor(event, '{Offline Players}', 'has enabled the offline player function.')
        else
            this.offline_players_enabled = false
            get_actor(event, '{Offline Players}', 'has disabled the offline player function.')
        end
    end,
    ['comfy_panel_collapse_grace'] = function(event)
        local WPT = package.loaded['maps.mountain_fortress_v3.table']
        local this = WPT.get()
        if event.element.switch_state == 'left' then
            this.collapse_grace = true
            get_actor(event, '{Collapse}', 'has enabled the collapse function. Collapse will occur after wave 100!')
        else
            this.collapse_grace = false
            get_actor(
                event,
                '{Collapse}',
                'has disabled the collapse function. You must reach zone 2 for collapse to occur!'
            )
        end
    end,
    ['comfy_panel_spill_items_to_surface'] = function(event)
        local WPT = package.loaded['maps.mountain_fortress_v3.table']
        local this = WPT.get()
        if event.element.switch_state == 'left' then
            this.spill_items_to_surface = true
            get_actor(
                event,
                '{Item Spill}',
                'has enabled the ore spillage function. Ores now drop to surface when mining.'
            )
        else
            this.spill_items_to_surface = false
            get_actor(
                event,
                '{Item Spill}',
                'has disabled the item spillage function. Ores no longer drop to surface when mining.'
            )
        end
    end,
    ['comfy_panel_void_or_tile'] = function(event)
        local WPT = package.loaded['maps.mountain_fortress_v3.table']
        local this = WPT.get()
        if event.element.switch_state == 'left' then
            this.void_or_tile = 'out-of-map'
            get_actor(event, '{Void}', 'has changes the tiles of the zones to: out-of-map (void)')
        else
            this.void_or_tile = 'lab-dark-2'
            get_actor(event, '{Void}', 'has changes the tiles of the zones to: dark-tiles (flammable tiles)')
        end
    end,
    ['comfy_panel_trusted_only_car_tanks'] = function(event)
        local WPT = package.loaded['maps.mountain_fortress_v3.table']
        local this = WPT.get()
        if event.element.switch_state == 'left' then
            this.trusted_only_car_tanks = true
            get_actor(event, '{Market}', 'has changed so only trusted people can buy car/tanks.', true)
        else
            this.trusted_only_car_tanks = false
            get_actor(event, '{Market}', 'has changed so everybody can buy car/tanks.', true)
        end
    end
}

local selection_functions = {
    ['comfy_panel_theme_dropdown'] = function(event)
        local player = game.get_player(event.player_index)
        if not player then return end
        local selected_index = event.element.selected_index
        local selected_style = gui_themes[selected_index].type
        local previous_style = global.gui_theme[player.name] or gui_themes[1].type
        if previous_style ~= selected_style then
            local label = event.element.parent.comfy_panel_theme_label
            label.caption = gui_themes[selected_index].name
            Gui.restyle_top_elements(player, selected_style)
        end
        global.gui_theme[player.name] = selected_style
    end
}

local function add_switch(element, switch_state, name, description_main, description, tooltip)
    local t = element.add({type = 'table', column_count = 5})
    
    local label = t.add({type = 'label', caption = 'ON'})
    label.style.padding = 0
    label.style.left_padding = 10
    label.style.font_color = {0.77, 0.77, 0.77}

    local switch = t.add({type = 'switch', name = name})
    switch.switch_state = switch_state
    switch.style.padding = 0
    switch.style.margin = 0
    
    local label = t.add({type = 'label', caption = 'OFF'})
    label.style.padding = 0
    label.style.font_color = {0.70, 0.70, 0.70}

    local label = t.add({type = 'label', caption = description_main})
    label.style.padding = 2
    label.style.left_padding = 10
    label.style.minimal_width = 140
    label.style.font = 'heading-2'
    label.style.font_color = {0.88, 0.88, 0.99}

    local label = t.add({type = 'label', caption = description, tooltip = tooltip})
    label.style.padding = 2
    label.style.left_padding = 10
    label.style.single_line = false
    label.style.font = 'heading-3'
    label.style.font_color = {0.85, 0.85, 0.85}

    return switch
end

function player_wants_pings(name)
    if global.want_pings[name] ~= nil then
        return global.want_pings[name]
    end
    return global.want_pings_default_value
end

local build_config_gui = (function(player, frame)
    local AG = Antigrief.get()
    local switch_state
    local label

    local admin = player.admin
    frame.clear()

    local scroll_pane =
        frame.add {
        type = 'scroll-pane',
        horizontal_scroll_policy = 'never'
    }
    local scroll_style = scroll_pane.style
    scroll_style.vertically_squashable = true
    scroll_style.padding = 2

    label = scroll_pane.add({type = 'label', caption = 'Player Settings'})
    label.style.font = 'default-bold'
    label.style.padding = 0
    label.style.left_padding = 10
    label.style.horizontal_align = 'left'
    label.style.vertical_align = 'bottom'
    label.style.font_color = {0.55, 0.55, 0.99}

    scroll_pane.add({type = 'line'})

    switch_state = 'right'
    if player.spectator then
        switch_state = 'left'
    end
    add_switch(
        scroll_pane,
        switch_state,
        'comfy_panel_spectator_switch',
        'SpectatorMode',
        'Toggles zoom-to-world view noise effect.\nEnvironmental sounds will be based on map view.'
    )

    scroll_pane.add({type = 'line'})

    switch_state = player_wants_pings(player.name) and 'left' or 'right'
    add_switch(
        scroll_pane,
        switch_state,
        'comfy_panel_want_pings_switch',
        'Ping on @' .. player.name,
        'Causes you to be clearly pinged on whispers and chat messages containing @' .. player.name
    )

    scroll_pane.add({type = 'line'})

    if global.auto_hotbar_enabled then
        switch_state = 'right'
        if global.auto_hotbar_enabled[player.index] then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_auto_hotbar_switch',
            'AutoHotbar',
            'Automatically fills your hotbar with placeable items.'
        )
        scroll_pane.add({type = 'line'})
    end

    if package.loaded['comfy_panel.poll'] then
        local poll = package.loaded['comfy_panel.poll']
        local poll_table = poll.get_no_notify_players()
        switch_state = 'right'
        if not poll_table[player.index] then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_poll_no_notify_toggle',
            'Notify on polls',
            'Receive a message when new polls are created and popup the poll.'
        )
        scroll_pane.add({type = 'line'})
    end

    if global.gui_theme ~= nil then
        local theme_idx = index_of(themes.keys, global.gui_theme[player.name]) or 1
        local theme_name = gui_themes[theme_idx].name

        local t = scroll_pane.add {type = 'table', column_count = 3}

        local label = t.add {type = 'label', name = 'comfy_panel_theme_label', ignored_by_interaction = true, caption = theme_name }
        label.style.padding = 0
        label.style.left_padding = 10
        label.style.font_color = {0.77, 0.77, 0.77}
        label.style.minimal_width = 100

        local label = t.add({type = 'label', caption = 'Top UI theme'})
        label.style.padding = 2
        label.style.left_padding = 10
        label.style.minimal_width = 140
        label.style.font = 'heading-2'
        label.style.font_color = {0.88, 0.88, 0.99}

        local dropdown = t.add { type = 'drop-down', style = 'dropdown', name = 'comfy_panel_theme_dropdown', items = themes.values, selected_index = theme_idx }
        dropdown.style.height = 24
        dropdown.style.natural_width = 200
        dropdown.style.left_margin = 10
        dropdown.style.vertical_align = 'center'

        scroll_pane.add({type = 'line'})
    end

    if admin then
        label = scroll_pane.add({type = 'label', caption = 'Admin Settings'})
        label.style.font = 'default-bold'
        label.style.padding = 0
        label.style.left_padding = 10
        label.style.top_padding = 10
        label.style.horizontal_align = 'left'
        label.style.vertical_align = 'bottom'
        label.style.font_color = {0.77, 0.11, 0.11}

        scroll_pane.add({type = 'line'})

        switch_state = 'right'
        if game.permissions.get_group('Default').allows_action(defines.input_action.open_blueprint_library_gui) then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_blueprint_toggle',
            'Blueprint Library',
            'Toggles the usage of blueprint strings and the library.'
        )

        scroll_pane.add({type = 'line'})

        switch_state = 'right'
        if global.comfy_panel_config.spaghett.enabled then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_spaghett_toggle',
            'Spaghett Mode',
            'Disables the Logistic System research.\nRequester, buffer or active-provider containers can not be built.'
        )

        if package.loaded['comfy_panel.poll'] then
            scroll_pane.add({type = 'line'})
            switch_state = 'right'
            if global.comfy_panel_config.poll_trusted then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_poll_trusted_toggle',
                'Poll mode',
                'Disables non-trusted plebs to create polls.'
            )
        end

        scroll_pane.add({type = 'line'})

        label = scroll_pane.add({type = 'label', caption = 'Antigrief Settings'})
        label.style.font = 'default-bold'
        label.style.padding = 0
        label.style.left_padding = 10
        label.style.top_padding = 10
        label.style.horizontal_align = 'left'
        label.style.vertical_align = 'bottom'
        label.style.font_color = Color.yellow

        switch_state = 'right'
        if AG.enabled then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_disable_antigrief',
            'Antigrief',
            'Left = Enables antigrief / Right = Disables antigrief'
        )
        scroll_pane.add({type = 'line'})
		
		
        if package.loaded['maps.biter_battles_v2.main'] then
            label = scroll_pane.add({type = 'label', caption = 'Biter Battles Settings'})
            label.style.font = 'default-bold'
            label.style.padding = 0
            label.style.left_padding = 10
            label.style.top_padding = 10
            label.style.horizontal_align = 'left'
            label.style.vertical_align = 'bottom'
            label.style.font_color = Color.green

            scroll_pane.add({type = 'line'})
			
			local switch_state = "right"
			if global.bb_settings.team_balancing then switch_state = "left" end
			local switch = add_switch(scroll_pane, switch_state, "bb_team_balancing_toggle", "Team Balancing", "Players can only join a team that has less or equal players than the opposing.")
			if not admin then switch.ignored_by_interaction = true end
			
			scroll_pane.add({type = 'line'})
			
			local switch_state = "right"
			if global.bb_settings["bb_map_reveal_toggle"] then switch_state = "left" end
			local switch = add_switch(scroll_pane, switch_state, "bb_map_reveal_toggle", "Reveal map", "Reveal map at start.")
			if not admin then switch.ignored_by_interaction = true end
				
			scroll_pane.add({type = 'line'})

			local switch_state = "right"
			if global.bb_settings.only_admins_vote then switch_state = "left" end
			local switch = add_switch(scroll_pane, switch_state, "bb_only_admins_vote", "Admin Vote", "Only admins can vote for map difficulty. Clears all currently existing votes.")
			if not admin then switch.ignored_by_interaction = true end
			
			scroll_pane.add({type = 'line'})
				
			local switch_state = "right"	
            if global.bb_settings.map_reroll then switch_state = "left" end
			local switch = add_switch(scroll_pane, switch_state, "bb_map_reroll_toggle", "Map Reroll", "Enables map reroll feature.")
			if not admin then switch.ignored_by_interaction = true end
			
			scroll_pane.add({type = 'line'})

			local switch_state = "right"	
            if global.bb_settings.burners_balance then switch_state = "left" end
			local switch = add_switch(scroll_pane, switch_state, "bb_burners_balance_toggle", "Burners balance", "Enables Burners balance.")
			if not admin then switch.ignored_by_interaction = true end
			
			scroll_pane.add({type = 'line'})
		end
		
        if package.loaded['maps.mountain_fortress_v3.main'] then
            label = scroll_pane.add({type = 'label', caption = 'Mountain Fortress Settings'})
            label.style.font = 'default-bold'
            label.style.padding = 0
            label.style.left_padding = 10
            label.style.top_padding = 10
            label.style.horizontal_align = 'left'
            label.style.vertical_align = 'bottom'
            label.style.font_color = Color.green

            local Fullness = package.loaded['modules.check_fullness']
            local full = Fullness.get()
            switch_state = 'right'
            if full.fullness_enabled then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_disable_fullness',
                'Inventory Fullness',
                'Left = Enables inventory fullness.\nRight = Disables inventory fullness.'
            )

            scroll_pane.add({type = 'line'})

            local WPT = package.loaded['maps.mountain_fortress_v3.table']
            local this = WPT.get()
            switch_state = 'right'
            if this.offline_players_enabled then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_offline_players',
                'Offline Players',
                'Left = Enables offline player inventory drop.\nRight = Disables offline player inventory drop.'
            )

            scroll_pane.add({type = 'line'})

            switch_state = 'right'
            if this.collapse_grace then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_collapse_grace',
                'Collapse',
                'Left = Enables collapse after wave 100.\nRight = Disables collapse - you must reach zone 2 for collapse to occur.'
            )

            scroll_pane.add({type = 'line'})

            switch_state = 'right'
            if this.spill_items_to_surface then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_spill_items_to_surface',
                'Spill Ores',
                'Left = Enables ore spillage to surface when mining.\nRight = Disables ore spillage to surface when mining.'
            )
            scroll_pane.add({type = 'line'})

            switch_state = 'right'
            if this.void_or_tile then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_void_or_tile',
                'Void Tiles',
                'Left = Changes the tiles to out-of-map.\nRight = Changes the tiles to lab-dark-2'
            )
            scroll_pane.add({type = 'line'})

            switch_state = 'right'
            if this.trusted_only_car_tanks then
                switch_state = 'left'
            end
            add_switch(
                scroll_pane,
                switch_state,
                'comfy_panel_trusted_only_car_tanks',
                'Market Purchase',
                'Left = Allows only trusted people to buy car/tanks.\nRight = Allows everyone to buy car/tanks.'
            )
            scroll_pane.add({type = 'line'})
        end


        label = scroll_pane.add({type = 'label', caption = 'Map Settings'})
        label.style.font = 'default-bold'
        label.style.padding = 0
        label.style.left_padding = 10
        label.style.top_padding = 10
        label.style.horizontal_align = 'left'
        label.style.vertical_align = 'bottom'
        label.style.font_color = Color.hot_pink

        switch_state = 'right'
        if global.bb_settings['new_year_island'] then
            switch_state = 'left'
        end
        add_switch(
            scroll_pane,
            switch_state,
            'comfy_panel_new_year_island',
            'New Year Island',
            'Add New Year(Christmass) theme decorations to spawn island (takes effect after map restart)'
        )
        scroll_pane.add({type = 'line'})

    end
    for _, e in pairs(scroll_pane.children) do
        if e.type == 'line' then
            e.style.padding = 0
            e.style.margin = 0
        end
    end
end)

local function on_gui_switch_state_changed(event)
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    if functions[event.element.name] then
        functions[event.element.name](event)
        return
    elseif antigrief_functions[event.element.name] then
        antigrief_functions[event.element.name](event)
        return
    elseif fortress_functions[event.element.name] then
        fortress_functions[event.element.name](event)
        return
    elseif package.loaded['comfy_panel.poll'] then
        if poll_function[event.element.name] then
            poll_function[event.element.name](event)
            return
        end
    end
end

local function on_gui_selection_state_changed(event)
    local ele = event.element
    if not (ele and ele.valid) then
        return
    end
    if selection_functions[ele.name] then
        selection_functions[ele.name](event)
        return
    end
end

local function on_force_created()
    spaghett()
end

local function on_built_entity(event)
    spaghett_deny_building(event)
end

local function on_robot_built_entity(event)
    spaghett_deny_building(event)
end

local function on_init()
    global.comfy_panel_config = {}
    global.comfy_panel_config.spaghett = {}
    global.comfy_panel_config.spaghett.undo = {}
    global.comfy_panel_config.poll_trusted = false
    global.comfy_panel_disable_antigrief = false
    global.want_pings = {}
    global.ping_gui_locations = {}
end

comfy_panel_tabs['Config'] = {gui = build_config_gui, admin = false}

local Event = require 'utils.event'
Event.on_init(on_init)
Event.add(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
Event.add(defines.events.on_force_created, on_force_created)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
