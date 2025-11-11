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

---@param player_index number?
---@return boolean, LuaPlayer?
local function check_player_permission(player_index)
    if not player_index then
        return false
    end

    ---@type LuaPlayer?
    local player = game.get_player(player_index)
    if not player or not player.valid then
        return false
    end

    if not is_admin(player) then
        player.print('This command can only be used by admins')
        return false
    end

    return true, player
end

---@param player LuaPlayer?
---@return boolean
local function try_destroy_bubble(player)
    local bubble = storage.announcement.entity
    if bubble and bubble.valid then
        local removed = bubble.destroy()
        if not removed then
            if player and player.valid then
                player.print('unknown problem occured when removing the announcement')
                player.print('save the game for later analysis')
            end
            return false
        end
    end

    return true
end

---Implements /announce command.
---If no parameter is set, it will clear existing announcement if any.
---If parameter is set, it will create new announcement or overwrite existing one.
---The announcement is supposed to persist across map resets.
---@param cmd CustomCommandData
local function announce(cmd)
    local allowed, player = check_player_permission(cmd.player_index)
    if not allowed then
        return
    end
    ---@cast player -nil

    -- In any case, we're going to clear existing announcement if any.
    local removed = try_destroy_bubble(player)
    if removed then
        Core.print_admins(player.name .. ' removed the announcement')
    else
        return
    end

    storage.announcement = {}
    local text = cmd.parameter
    if not text then
        return
    end

    text = text:gsub('\\n', '\n')

    storage.announcement.text = '[font=var]' .. text .. '[/font]'
    Core.print_admins(player.name .. ' made an announcement')
    Public.announce_if_any()
end

commands.add_command('announce', 'Creates a text at spectator island', function(cmd)
    Utils.safe_wrap_cmd(cmd, announce, cmd)
end)

---Implements /announce-append command.
---If no parameter is set, does nothing.
---If parameter is set, it will create new announcement if none exist or append existing one.
---The announcement is supposed to persist across map resets.
---@param cmd CustomCommandData
local function announce_append(cmd)
    local allowed, player = check_player_permission(cmd.player_index)
    if not allowed then
        return
    end
    ---@cast player -nil

    local text = cmd.parameter
    if not text then
        return
    end

    -- In any case, we're going to clear existing announcement if any.
    local removed = try_destroy_bubble(player)
    if not removed then
        return
    end

    text = text:gsub('\\n', '\n')

    if storage.announcement.text then
        storage.announcement.text = storage.announcement.text .. '[font=var]' .. text .. '[/font]'
        Core.print_admins(player.name .. ' appended an announcement')
    else
        storage.announcement.text = '[font=var]' .. text .. '[/font]'
        Core.print_admins(player.name .. ' made an announcement')
    end
    Public.announce_if_any()
end

commands.add_command('announce-append', 'Appends to the text at spectator island', function(cmd)
    Utils.safe_wrap_cmd(cmd, announce_append, cmd)
end)

return Public
