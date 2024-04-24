local Color = require 'utils.color_presets'

local function generate_alt_threatfarming(defender_mult, spawner_mult)
    --Setup gamemode.
    global.active_special_games["alt_threatfarming"] = true
    if not global.special_games_variables["alt_threatfarming"] then
        global.special_games_variables["alt_threatfarming"] = {}
    end
    global.special_games_variables["alt_threatfarming"]["defender_mult"] = defender_mult
    global.special_games_variables["alt_threatfarming"]["spawner_mult"] = spawner_mult
    global.special_games_variables["alt_threatfarming"]["spawner_biter_ids"] = {}
    global.special_games_variables["alt_threatfarming"]["attack_biter_ids"] = {}
    --We only want to apply this logic to biters - threat for worms and spawners should not be affected.
    global.special_games_variables["alt_threatfarming"]["affected_entities"] = {
        ["small-spitter"] = true,
        ["small-biter"] = true,
        ["medium-spitter"] = true,
        ["medium-biter"] = true,
        ["big-spitter"] = true,
        ["big-biter"] = true,
        ["behemoth-spitter"] = true,
        ["behemoth-biter"] = true
    }
    local special_game_description = "Biters defending spawners are worth " .. tostring(defender_mult) .. "x threat. Biters inside spawners are worth " .. tostring(spawner_mult) .. "x threat!"
    --Create floating text.
    if global.special_games_variables["alt_threatfarming"]["text_id"] then
        rendering.destroy(global.special_games_variables["alt_threatfarming"]["text_id"])
    end
    global.special_games_variables["alt_threatfarming"]["text_id"] = rendering.draw_text{
        text = special_game_description,
        surface = game.surfaces[global.bb_surface_name],
        target = {-0,12},
        color = Color.warning,
        scale = 3,
        alignment = "center",
        scale_with_zoom = false
    }
    --Send message.
    game.print("[SPECIAL GAMES] Alternate threatfarming enabled)", Color.warning)
    game.print("[SPECIAL GAMES] " .. special_game_description, Color.warning)
end

local Public = {
    name = {type = "label", caption = "Alternate Threatfarming", tooltip = "Biters defending spawners are worth less threat, biters inside spawners are worth more."},
    config = {
        [1] = {name = "label1", type = "label", caption = "Multiplier for defender biters:"},
        [2] = {name = "defender_mult", type = "textfield", text = "0.5", numeric = true, width = 40},
        [3] = {name = "label2", type = "label", caption = "Multiplier for spawner biters:"},
        [4] = {name = "spawner_mult", type = "textfield", text = "5", numeric = true, width = 40},
    },
    button = {name = "apply", type = "button", caption = "Apply"},
    generate = function (config, player)
        local defender_mult = tonumber(config["defender_mult"].text)
        local spawner_mult = tonumber(config["spawner_mult"].text)
        generate_alt_threatfarming(defender_mult, spawner_mult)
    end
}

return Public
