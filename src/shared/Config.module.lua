--[[
    Config.module.lua

    A centralized module to hold all game configuration values.
    This allows for easy tuning and ensures consistency across client and server scripts.
]]

local Config = {
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 180,
    POST_ROUND_DURATION = 5,
    KILLER_SPAWN_DELAY = 5,
    MIN_PLAYERS = 5,
    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
    MACHINES_TO_SPAWN = 3,
    VICTORY_GATE_TIMER = 30,
    MACHINE_BONUS_TIME = 5,
    GRAB_DISTANCE = 10,
    CARRYING_SPEED_PENALTY = 0.95,
}

return Config
