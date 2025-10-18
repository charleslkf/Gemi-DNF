--[[
    InitializeRemotes.server.lua

    This script's only purpose is to create all necessary RemoteEvent instances
    in a centralized, reliable location (ReplicatedStorage.Remotes).
    Because it is in ServerScriptService, it is guaranteed to run on server startup
    before any other client or server script tries to access these events.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure the Remotes folder exists
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

-- A table of all remote event names to create
local eventNames = {
    "ShowNotification",
    "ResetRoundRequest",
    "StartRoundRequest",
    "MachineFixed",
    "DownedStateChanged",
    "AttackRequest",
    "PlayerCaged",
    "PlayerRescued",
    "EliminationEvent",
    "GameStateChanged",
    "HealthChanged",
    "EscapeSequenceStarted"
}

-- Create each event if it doesn't exist
for _, name in ipairs(eventNames) do
    if not remotes:FindFirstChild(name) then
        Instance.new("RemoteEvent", remotes).Name = name
    end
end

print("InitializeRemotes: All RemoteEvents created and verified.")