--[[
    HealthClient.client.lua
    by Jules

    This script listens for health-related events from the server
    and calls the appropriate UI functions in the HealthManager module.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local healthChangedEvent = remotes:WaitForChild("HealthChanged")

-- Event Listener
healthChangedEvent.OnClientEvent:Connect(function(currentHealth, maxHealth)
    HealthManager.createOrUpdateHealthBar(currentHealth, maxHealth)
end)

print("HealthClient.client.lua loaded and listening.")
