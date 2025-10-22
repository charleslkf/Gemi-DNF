--[[
    CagingClient.client.lua
    by Jules

    This script listens for caging-related events from the server
    and calls the appropriate UI functions in the CagingManager module.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerCagedEvent = remotes:WaitForChild("PlayerCaged")
local playerRescuedEvent = remotes:WaitForChild("PlayerRescued")
local playerRescuedClientEvent = remotes:WaitForChild("PlayerRescued_CLIENT")

-- Event Listeners
playerCagedEvent.OnClientEvent:Connect(function(cagedPlayer, duration)
    CagingManager.showCageUI(cagedPlayer, duration)
end)

playerRescuedEvent.OnClientEvent:Connect(function(rescuedPlayer)
    CagingManager.hideCageUI(rescuedPlayer)
end)

playerRescuedClientEvent.OnClientEvent:Connect(function(rescuedPlayerCharacter)
    -- The server sends the character model, we need the player object
    local rescuedPlayer = game.Players:GetPlayerFromCharacter(rescuedPlayerCharacter)
    if rescuedPlayer then
        CagingManager.hideCageUI(rescuedPlayer)
    end
end)

print("CagingClient.client.lua loaded and listening.")
