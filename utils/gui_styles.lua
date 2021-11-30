local Public = {}

function Public.element_style(options)
	local element = options.element
	element.style.width = options.x
	element.style.height = options.y
	element.style.padding = options.pad
end

function Public.colored_text(text, color)
	return table.concat({"[color=", color.r, ",", color.g, ",", color.b, "]", text, "[/color]"})
end

function Public.colored_player(player)
	if not player.valid then return end
	return table.concat({"[color=", player.color.r * 0.6 + 0.35, ",", player.color.g * 0.6 + 0.35, ",", player.color.b * 0.6 + 0.35, "]", player.name, "[/color]"})
end

return Public

