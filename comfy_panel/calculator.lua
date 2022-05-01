local Tables = require("maps.biter_battles_v2.tables")
local Tabs = require("comfy_panel.main")
local Feeding = require("maps.biter_battles_v2.feeding")
local Event = require("utils.event")

local BASE_TAB_FRAME_NAME = "tab_base"

local CALCULATOR_TAB_NAME = "Calculator"
local CALCULATOR_V1_BASE = "calculator_vert_base"
local CALCULATOR_H2_BASE = "calculator_hori_base"
local CALCULATOR_CALCULATOR = "calculator_calculator"
local CALCULATOR_RESULTS = "calculator_results"

local CALCULATOR_STARTING_EVO_TEXT_INPUT_NAME = "calculator_starting_evo_input"
local CALCULATOR_TARGET_EVO_TEXT_INPUT_NAME = "calculator_target_evo_input"

local CALCULATOR_FINAL_EVO_TEXT_RESULT_NAME = "calculator_final_evo_result"

local CALCULATOR_INPUT_FOOD_PREFIX = "calculator_input_"
local CALCULATOR_TARGET_FOOD_PREFIX = "calculator_result_"
local CALCULATOR_BUTTON = "calculator_button"
local CALCULATOR_ERROR_TEXT = "calculator_error_text"

local PRESET_TABLE_FRAME_NAME = "calculator_preset_frame"
local PRESET_TABLE_TABLE_NAME = "calculator_preset_table"
local PRESET_TABLE_UPDATE_BUTTON = "calculator_preset_update_button"
local PRESET_TABLE_UPDATE_ERR_TEXT = "calculator_error_text"

local CALC_HELP_TEXT = "When Starting and Target Evo is set, we will calculate the number of flasks required to"
	.. " advance from the Starting Evo to the Target Evo.  When Target Evo is not set, but numbers in the science"
	.. " are set, we will calculate the Final Evo given the total number of flasks sent."

local MAXIMUM_CALC_LIM = 500000

local function get_upcoming_biter_tier_list_from_current_evo(evo)
	local biters_tiers = {}
	if evo < Tables.biter_mutagen_thresholds["medium"] then
		table.insert(biters_tiers, "medium")
	end
	if evo < Tables.biter_mutagen_thresholds["big"] then
		table.insert(biters_tiers, "big")
	end
	if evo < Tables.biter_mutagen_thresholds["behemoth"] then
		table.insert(biters_tiers, "behemoth")
	end
	return biters_tiers
end

local function calculate_evo_from_food_and_value(current_evo, current_evo_factor, food_value, num_food)
	local evo = current_evo
	local evo_factor = current_evo_factor
	for _ = 1, num_food do
		local e2 = Feeding.calculate_e2(evo_factor)
		local evo_gain = Feeding.evo_gain_from_one_flask(food_value, e2)
		evo = evo + evo_gain
		evo_factor = Feeding.get_new_evo_factor_from_evolution(evo)
	end
	return evo
end

local function calculate_needed_food(target_evo, current_evo, current_evo_factor, food_value)
	local evo = current_evo
	local evo_factor = current_evo_factor
	local count = 0
	while evo * 1000 < target_evo do
		local e2 = Feeding.calculate_e2(evo_factor)
		local evo_gain = Feeding.evo_gain_from_one_flask(food_value, e2)
		evo = evo + evo_gain
		evo_factor = Feeding.get_new_evo_factor_from_evolution(evo)
		count = count + 1
		if count >= MAXIMUM_CALC_LIM then
			return nil
		end
	end
	return count
end

local function get_red_to_x_multiplier_list()
	local multer = {}
	for k, v in pairs(Tables.food_values) do
		multer[k] = Tables.food_values["automation-science-pack"].value / v.value
	end
	return multer
end

local function get_total_red_flasks_per_biter_tier_map(upcoming_biter_list, current_evo, current_evo_factor)
	local total_red_flasks_per_biter_tier = {}
	for _, v in ipairs(upcoming_biter_list) do
		total_red_flasks_per_biter_tier[v] = 0
	end

	local working_current_evo = current_evo
	local working_current_evo_factor = current_evo_factor
	for _, v in ipairs(upcoming_biter_list) do
		local c_threshold = Tables.biter_mutagen_thresholds[v]
		local needed = calculate_needed_food(
			c_threshold,
			working_current_evo,
			working_current_evo_factor,
			Tables.food_values["automation-science-pack"].value * global.difficulty_vote_value
		)
		if needed == nil then
			return nil
		end
		working_current_evo = c_threshold / 1000.0
		working_current_evo_factor = c_threshold / 1000.0
		total_red_flasks_per_biter_tier[v] = needed
	end
	return total_red_flasks_per_biter_tier
end

local function add_biter_puberty_thresholds_for_team(frame, t, team)
	local biter_force_name = team .. "_biters"
	local current_evo = global.bb_evolution[biter_force_name]
	local upcoming_biter_list = get_upcoming_biter_tier_list_from_current_evo(current_evo*1000.0)
	local current_evo_factor = game.forces[biter_force_name].evolution_factor

	t.add({ type = "label", caption = team })
	t.add({ type = "label", caption = "Evo: " .. string.format("%.1f", current_evo * 100.0) })
	for _ = 1, 6 do
		t.add({ type = "label", caption = "" })
	end

	if #upcoming_biter_list == 0 then return end

	t.add({ type = "label", caption = "" })
	for k, _ in pairs(Tables.food_values) do
		t.add({ type = "sprite", sprite = "item/" .. k })
	end

	local red_ratio_mult = get_red_to_x_multiplier_list()
	local total_red_flasks_per_biter_tier = get_total_red_flasks_per_biter_tier_map(
		upcoming_biter_list,
		current_evo,
		current_evo_factor
	)
	if total_red_flasks_per_biter_tier == nil then
		t[CALCULATOR_ERROR_TEXT].caption = "ERR: >=" .. MAXIMUM_CALC_LIM
		return
	end

	for _, v in ipairs(upcoming_biter_list) do
		t.add({ type = "sprite", sprite = "entity/" .. v .. "-biter" })
		for k, _ in pairs(Tables.food_values) do
			local needed = math.ceil(total_red_flasks_per_biter_tier[v] * red_ratio_mult[k])
			t.add({ type = "label", caption = string.format("%7d", needed) })
		end
	end
	for _ = 1, 8 do
		t.add({ type = "label", caption = "" })
	end
end

local function create_preset_table_frame(f)
	local t = f.add({
		name = PRESET_TABLE_TABLE_NAME,
		type = "table",
		column_count = 8,
		vertical_centering = false,
	})
	for x = 1, 8 do
		t.style.column_alignments[x] = "right"
	end

	for _, x in pairs({ "north", "south" }) do
		add_biter_puberty_thresholds_for_team(f, t, x)
	end

	f.add({ name = PRESET_TABLE_UPDATE_BUTTON, type = "button", caption = "REFRESH" })
	f.add({ name = PRESET_TABLE_UPDATE_ERR_TEXT, type = "label", caption = "" })
end

local function add_biter_puberty_thresholds_to_frame(f)
	local sub_f = f.add({
		name = PRESET_TABLE_FRAME_NAME,
		type = "frame",
		direction = "vertical",
		style = "borderless_frame",
	})
	create_preset_table_frame(sub_f)
end

local function get_CALC_CALC(f)
	return f[BASE_TAB_FRAME_NAME][CALCULATOR_V1_BASE][CALCULATOR_H2_BASE][CALCULATOR_CALCULATOR]
end

local function get_CALC_RES(f)
	return f[BASE_TAB_FRAME_NAME][CALCULATOR_V1_BASE][CALCULATOR_H2_BASE][CALCULATOR_RESULTS]
end

local function add_calculator(frame)
	local v1_frame = frame.add({
		name = CALCULATOR_V1_BASE,
		type = "frame",
		direction = "vertical",
		style = "borderless_frame",
	})
	local h2_frame = v1_frame.add({ name = CALCULATOR_H2_BASE, type = "frame", style = "borderless_frame" })

	local t = h2_frame.add({
		name = CALCULATOR_CALCULATOR,
		type = "table",
		column_count = 2,
		vertical_centering = false,
	})
	t.style.column_alignments[1] = "left"
	t.style.column_alignments[2] = "right"

	t.add({ type = "label", caption = "Starting Evo:" })
	local starting_evo_tb = t.add({ name = CALCULATOR_STARTING_EVO_TEXT_INPUT_NAME, type = "textfield", text = "0" })
	starting_evo_tb.style.width = 50
	starting_evo_tb.style.horizontal_align = "right"

	t.add({ type = "label", caption = "Target Evo:" })
	local target_evo_tb = t.add({ name = CALCULATOR_TARGET_EVO_TEXT_INPUT_NAME, type = "textfield" })
	target_evo_tb.style.width = 50
	target_evo_tb.style.horizontal_align = "right"

	for k, _ in pairs(Tables.food_values) do
		t.add({ type = "sprite", sprite = "item/" .. k })
		local c_food_box = t.add({ name = CALCULATOR_INPUT_FOOD_PREFIX .. k, type = "textfield" })
		c_food_box.style.width = 50
		c_food_box.style.horizontal_align = "right"
	end

	t.add({ name = CALCULATOR_BUTTON, type = "button", caption = "CALCULATE" })
	t.add({ name = CALCULATOR_ERROR_TEXT, type = "label", caption = "" })

	local t2 = h2_frame.add({ name = CALCULATOR_RESULTS, type = "table", column_count = 2, vertical_centering = false })
	t2.style.column_alignments[1] = "left"
	t2.style.column_alignments[2] = "right"

	t2.add({ type = "label", caption = "Final Evo:" })
	t2.add({ name = CALCULATOR_FINAL_EVO_TEXT_RESULT_NAME, type = "label", caption = "_" })
	t2.add({ type = "label", caption = "Food Required:" })
	t2.add({ type = "label", caption = "" })
	for k, _ in pairs(Tables.food_values) do
		t2.add({ type = "sprite", sprite = "item/" .. k })
		t2.add({ name = CALCULATOR_TARGET_FOOD_PREFIX .. k, type = "label" })
	end
	local helplabel = v1_frame.add({ type = "label", caption = CALC_HELP_TEXT })
	helplabel.style.maximal_width = 500
	helplabel.style.single_line = false
end

local function reset_calculator_text(frame)
	get_CALC_CALC(frame)[CALCULATOR_ERROR_TEXT].caption = ""
	for k, _ in pairs(Tables.food_values) do
		local target_food_ele_name = CALCULATOR_TARGET_FOOD_PREFIX .. k
		get_CALC_RES(frame)[target_food_ele_name].caption = ""
	end
	get_CALC_RES(frame)[CALCULATOR_FINAL_EVO_TEXT_RESULT_NAME].caption = ""
end

local function handle_calculator_button(frame)
	local target_evo_input_text = get_CALC_CALC(frame)[CALCULATOR_TARGET_EVO_TEXT_INPUT_NAME].text
	reset_calculator_text(frame)

	if target_evo_input_text ~= "" then
		local starting_evo_number = tonumber(get_CALC_CALC(frame)[CALCULATOR_STARTING_EVO_TEXT_INPUT_NAME].text)
		if starting_evo_number == nil then
			return
		end
		starting_evo_number = starting_evo_number / 100.0
		local target_evo_number = tonumber(target_evo_input_text)
		if target_evo_number == nil then
			return
		end
		target_evo_number = target_evo_number * 10.0

		local red_ratio_mult = get_red_to_x_multiplier_list()

		local needed_food_for_red = calculate_needed_food(
			target_evo_number,
			starting_evo_number,
			Feeding.get_new_evo_factor_from_evolution(starting_evo_number),
			Tables.food_values["automation-science-pack"].value * global.difficulty_vote_value
		)
		if needed_food_for_red == nil then
			get_CALC_CALC(frame)[CALCULATOR_ERROR_TEXT].caption = "ERR: >=" .. MAXIMUM_CALC_LIM
			return
		end

		for k, _ in pairs(Tables.food_values) do
			local target_food_ele_name = CALCULATOR_TARGET_FOOD_PREFIX .. k
			get_CALC_RES(frame)[target_food_ele_name].caption = tostring(
				math.ceil(needed_food_for_red * red_ratio_mult[k])
			)
		end
	else
		local starting_evo_number = tonumber(get_CALC_CALC(frame)[CALCULATOR_STARTING_EVO_TEXT_INPUT_NAME].text)
		if starting_evo_number == nil then
			return
		end

		starting_evo_number = starting_evo_number / 100.0

		for k, v in pairs(Tables.food_values) do
			local target_food_ele_name = CALCULATOR_INPUT_FOOD_PREFIX .. k
			local current_food_input_num = tonumber(get_CALC_CALC(frame)[target_food_ele_name].text)
			if current_food_input_num ~= nil and current_food_input_num ~= 0 then
				if current_food_input_num >= MAXIMUM_CALC_LIM then
					frame[CALCULATOR_ERROR_TEXT].caption = "ERR: >=" .. MAXIMUM_CALC_LIM
					return
				end
				starting_evo_number = calculate_evo_from_food_and_value(
					starting_evo_number,
					Feeding.get_new_evo_factor_from_evolution(starting_evo_number),
					v.value * global.difficulty_vote_value,
					current_food_input_num
				)
			end
		end
		get_CALC_RES(frame)[CALCULATOR_FINAL_EVO_TEXT_RESULT_NAME].caption = string.format(
			"%.1f",
			starting_evo_number * 100.0
		)
	end
end

local function handle_preset_table_update(frame)
	if frame[BASE_TAB_FRAME_NAME][PRESET_TABLE_FRAME_NAME] ~= nil then
		frame[BASE_TAB_FRAME_NAME][PRESET_TABLE_FRAME_NAME].destroy()
	end
	add_biter_puberty_thresholds_to_frame(frame[BASE_TAB_FRAME_NAME])
	frame[BASE_TAB_FRAME_NAME].swap_children(4, 3)
	frame[BASE_TAB_FRAME_NAME].swap_children(3, 2)
	frame[BASE_TAB_FRAME_NAME].swap_children(2, 1)
end

local function on_gui_click(event)
	local player = game.players[event.player_index]
	local frame = Tabs.comfy_panel_get_active_frame(player)
	if not frame or (frame.name ~= CALCULATOR_TAB_NAME) then
		return
	end

	if event.element.name == CALCULATOR_BUTTON then
		handle_calculator_button(frame)
	elseif event.element.name == PRESET_TABLE_UPDATE_BUTTON then
		handle_preset_table_update(frame)
	end
end

local show_calculator = function(player, frame)
	if frame[BASE_TAB_FRAME_NAME] then
		frame[BASE_TAB_FRAME_NAME].destroy()
	end
	local m_frame = frame.add({ name = BASE_TAB_FRAME_NAME, type = "frame", style = "borderless_frame" })
	add_biter_puberty_thresholds_to_frame(m_frame)
	local pad_frame = m_frame.add({ type = "frame", style = "borderless_frame" })
	pad_frame.add({ type = "line", direction = "vertical" })
	pad_frame.add({ type = "line", direction = "vertical" })
	pad_frame.add({ type = "line", direction = "vertical" })
	add_calculator(m_frame)
end

comfy_panel_tabs[CALCULATOR_TAB_NAME] = { gui = show_calculator, admin = false }

Event.add(defines.events.on_gui_click, on_gui_click)
