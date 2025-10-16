--[[
    GameStateManager.module.lua
    by Jules

    This server-side module is the single source of truth for all
    replicated game state information that the client HUD needs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local MachineFixed = Remotes:WaitForChild("MachineFixed")

local GameStateManager = {}

-- The central table holding the current state of the game
local gameState = {
    Name = "Waiting",
    Timer = 0,
    MachinesTotal = 3, -- Default value, can be updated
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

function GameStateManager:SetStateName(newStateName)
    if gameState.Name ~= newStateName then
        gameState.Name = newStateName
        _broadcastState()
    end
end

function GameStateManager:SetNewRoundState(roundDuration, machinesTotal)
    gameState.Timer = roundDuration
    gameState.MachinesTotal = machinesTotal or 3 -- Use provided total, or default
    gameState.MachinesCompleted = 0
    gameState.Kills = 0
    _broadcastState()
    print("GameStateManager: Set new round state.")
end

function GameStateManager:AreAllMachinesRepaired()
    return gameState.MachinesCompleted >= gameState.MachinesTotal
end

function GameStateManager:IncrementMachinesCompleted()
    gameState.MachinesCompleted = gameState.MachinesCompleted + 1
    _broadcastState()
end

function GameStateManager:IncrementKills()
    print("GameStateManager: IncrementKills() called.")
    gameState.Kills = gameState.Kills + 1
    _broadcastState()
end

function GameStateManager.initialize()
    print("GameStateManager initialized.")
end

return GameStateManager
