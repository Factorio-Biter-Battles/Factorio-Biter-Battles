local color_presets = require "utils.color_presets"

local Public = {
   name = {type = "label", caption = "threat threshold", tooltip= "threat cant fall below threshold, fraction of excess threat is send to enemy"},
   config = {
    [1] = {name = "label1", type = "label", caption = "minimum threat amount"},
    [2] = {name = "threat_farm_threshold", type = "textfield", width = 40, text=0},
    [3] = {name = "label2", type = "label", caption="fraction of excess threat, send to enemy"},
    [4] = {name = "threat_farm_send_fraction", type= "textfield", width = 40, text=0.5},
   },
   button = {name = "apply", type= "button", caption = "Apply"},
   generate = function (config, player)
        if(not tonumber(config["threat_farm_threshold"].text)or not tonumber(config["threat_farm_send_fraction"].text)) then
            game.print("invalid configuration, only numbers allowed",color_presets.warning)
            return
        end

        global.active_special_games["threat_farm_threshold"] = true
        global.special_games_variables["threat_farm_threshold"] = tonumber(config["threat_farm_threshold"].text)
        global.special_games_variables["threat_farm_send_fraction"] = tonumber(config["threat_farm_send_fraction"].text)

        
        
        game.print("excess threat below " .. global.special_games_variables["threat_farm_threshold"] .. " will be added to opponent with a factor of " .. global.special_games_variables["threat_farm_send_fraction"], color_presets.warning)
    end,
}
return Public