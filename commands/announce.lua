local Utils = require('utils.utils')
local Core = require('utils.core')
local Public = {}

---Spawns announcement speech-bubble. It's supposed to be called on every
---map reset and on-demand.
Public.announce_if_any = function()
    local announcement = storage.announcement
    if not announcement.text then
        return
    end

    ---@type LuaSurface
    local s = game.surfaces[storage.bb_surface_name]
    local e = s.create_entity({
        name = 'entity-ghost',
        inner_name = 'steel-chest',
        position = { 0, 15 },
        force = 'enemy',
        create_build_effect_smoke = false,
        minable_flag = false,
        operable = false,
        destructible = false,
    })

    s.create_entity({
        name = 'compi-speech-bubble',
        text = announcement.text,
        source = e,
        position = e.position,
        create_build_effect_smoke = false,
    })

    announcement.entity = e
end

---Implements /announce command.
---If no parameter is set, it will clear existing announcement if any.
---If parameter is set, it will create new announcement or overwrite existing one.
---The announcement is supposed to persist across map resets.
---@param cmd CustomCommandData
local function announce(cmd)
    ---@type number?
    local index = cmd.player_index
    if not index then
        return
    end

    ---@type LuaPlayer?
    local player = game.get_player(index)
    if not player or not player.valid then
        return
    end

    if not player.admin then
        player.print('This command can only be used by admins')
        return
    end

    -- In any case, we're going to clear existing announcement if any.
    local removed = false
    local bubble = storage.announcement.entity
    if bubble and bubble.valid then
        removed = bubble.destroy()
        if not removed then
            player.print('unknown problem occured when removing the announcement')
            player.print('save the game for later analysis')
            return
        end
    end

    storage.announcement = {}
    local text = cmd.parameter
    if not text then
        if removed then
            Core.print_admins(player.name .. ' removed the announcement')
        end

        return
    end

    text = text:gsub("\\n", "\n")

    storage.announcement.text = '[font=var]' .. text .. '[/font]'
    Core.print_admins(player.name .. ' made an announcement')
    Public.announce_if_any()
end

commands.add_command('announce', 'Creates a text at spectator island', function(cmd)
    Utils.safe_wrap_cmd(cmd, announce, cmd)
end)

return Public
