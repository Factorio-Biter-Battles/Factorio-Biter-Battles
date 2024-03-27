--Adds a small gui to quick select an icon tag for your character - mewmew

local Event = require 'utils.event'
local gui_style = require 'utils.utils'.gui_style
local icons = {
	{"[img=item/electric-mining-drill]", "item/electric-mining-drill", "Miner"},
	{"[img=item/stone-furnace]", "item/stone-furnace", "Smeltery"},
	{"[img=item/big-electric-pole]", "item/big-electric-pole", "Power"},
	{"[img=item/assembling-machine-1]", "item/assembling-machine-1", "Production"},
	{"[img=item/chemical-science-pack]", "item/chemical-science-pack", "Science"},
	{"[img=item/locomotive]", "item/locomotive", "Trainman"},	
	{"[img=fluid/crude-oil]", "fluid/crude-oil", "Oil processing"},	
	{"[img=item/submachine-gun]", "item/submachine-gun", "Trooper"},
	{"[img=item/stone-wall]", "item/stone-wall", "Fortifications"},
	{"[img=item/repair-pack]", "item/repair-pack", "Support"},	
}

local checks = {
	"minimal_width", "left_margin", "right_margin"
}
local Public = {}

local function get_x_offset(player)
	local x = 0
	for _, element in pairs(player.gui.top.children) do
		if element.name == "simple_tag" then break end		
		local style = element.style
		for _, v in pairs(checks) do
			if style[v] then
				x = x + style[v]
			end
		end
	end
	return x
end

local function draw_top_gui(player)
	if player.gui.top.simple_tag then return end
	local button = player.gui.top.add({type = "sprite-button", name = "simple_tag", caption = "Tag"})
	button.style.font = "heading-2"
	button.style.font_color = {212, 212, 212}
	gui_style(button, {width = 38, height = 38, padding = -2})
end

local function draw_screen_gui(player)
	local frame = player.gui.screen.simple_tag_frame
	if player.gui.screen.simple_tag_frame then
		frame.destroy()
		return
	end		
	
	local frame = player.gui.screen.add({
		type = "frame",
		name = "simple_tag_frame",
		direction = "vertical",
	})	
	frame.location = {x = get_x_offset(player) * player.display_scale - 2, y = 39 * player.display_scale}
	frame.style.padding = -2
	frame.style.maximal_width = 42
	
	for _, v in pairs(icons) do
		local button = frame.add({type = "sprite-button", name = v[1], sprite = v[2], tooltip = v[3]})
		gui_style(button, {width = 38, height = 38, padding = -2})
	end
	
	local tag = player.tag
	if not tag then return end
	if string.len(tag) < 8 then return end
	local clear_tag_element = frame[tag]
	if not clear_tag_element then return end
	clear_tag_element.sprite = "utility/close_white"
	clear_tag_element.tooltip = "Clear Tag"	
end

local function on_player_joined_game(event)
	local player = game.players[event.player_index]
	draw_top_gui(player)
end


---@param player LuaPlayer
---@param element LuaGuiElement
function Public.on_gui_click(player, element)
	local name = element.name
	if name == "simple_tag" then
		draw_screen_gui(player)
		return
	end

	local parent = element.parent
	if not parent then return end
	if not parent.valid then return end
	if not parent.name then return end
	if parent.name ~= "simple_tag_frame" then return end

	local selected_tag = element.name

	if player.tag == selected_tag then	selected_tag = "" end
	player.tag = selected_tag
	parent.destroy()
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
return Public
