--[[
    GameStateManager.module.lua
    by Jules

    This server-side module is the single source of truth for all
    replicated game state information that the client HUD needs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")

local GameStateManager = {}

-- The central table holding the current state of the game
local gameState = {
    Timer = 0,
    MachinesTotal = 9, -- Default value, can be updated
    MachinesCompleted = 0,
    Kills = 0
}

-- Private function to broadcast the latest state to all clients
local function _broadcastState()
    GameStateChanged:FireAllClients(gameState)
end

-- Public functions for other server scripts to update the state

function GameStateManager:SetTimer(newTime)
    if gameState.Timer ~= newTime then
        gameState.Timer = newTime
        _broadcastState()
    end
end

function GameStateManager:SetNewRoundState(roundDuration)
    gameState.Timer = roundDuration
    -- In the future, we can get the real machine count from MapManager
    gameState.MachinesCompleted = 0
    gameState.Kills = 0
    _broadcastState()
    print("GameStateManager: Set new round state.")
end

function GameStateManager:IncrementMachinesCompleted()
    gameState.MachinesCompleted = gameState.MachinesCompleted + 1
    _broadcastState()
end

function GameStateManager:IncrementKills()
    gameState.Kills = gameState.Kills + 1
    _broadcastState()
end

function GameStateManager.initialize()
    print("GameStateManager initialized.")
    -- The module is now stateful, initialization can be used for more complex setup later.
end

return GameStateManager
