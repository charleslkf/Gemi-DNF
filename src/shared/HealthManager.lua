--[[
    HealthManager.lua
    by Jules

    A self-contained module to manage player health, damage, and UI.
    This module has code paths for both the server (authoritative logic)
    and the client (UI management).
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Table
local HealthManager = {}

-- Constants
local DEFAULT_MAX_HEALTH = 100
local HEALTH_BAR_UI_NAME = "HealthBarGui"

-----------------------------------------------------------------------------
-- SERVER-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsServer() then
    -- Forward declaration for lazy loading
    local CagingManager

    local healthData = {} -- { [Player]: { current: number, max: number } }
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local healthChangedEvent = remotes:WaitForChild("HealthChanged")

    -- Initializes a player's health and informs their client to create the UI.
    function HealthManager.initializeHealth(player, maxHealth)
        maxHealth = maxHealth or DEFAULT_MAX_HEALTH
        print(string.format("Server: Initializing health for %s to %d.", player.Name, maxHealth))

        healthData[player] = {
            current = maxHealth,
            max = maxHealth,
        }

        -- Tell the client to create/update their health bar
        healthChangedEvent:FireClient(player, maxHealth, maxHealth)
    end

    -- Returns the current health of a player.
    function HealthManager.getHealth(player)
        if healthData[player] then
            return healthData[player].current
        end
        return nil
    end

    -- Applies damage to a player and checks for elimination.
    function HealthManager.applyDamage(player, amount, damageDealer) -- damageDealer can be nil
        if not CagingManager then
            CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
        end

        if not healthData[player] then
            warn(string.format("Attempted to apply damage to %s, but they have no health data.", player.Name))
            return
        end

        local data = healthData[player]
        data.current = math.max(0, data.current - amount)

        print(string.format("Server: Applied %d damage to %s. New health: %d", amount, player.Name, data.current))

        -- Tell the client to update their health bar
        healthChangedEvent:FireClient(player, data.current, data.max)

        -- Check for elimination
        if data.current <= 0 then
            healthData[player] = nil -- Clear health data before elimination
            CagingManager.eliminatePlayer(player, damageDealer)
        end
    end

    -- Cleanup function for when a player leaves
    Players.PlayerRemoving:Connect(function(player)
        if healthData[player] then
            healthData[player] = nil
            print(string.format("Server: Cleared health data for disconnected player %s.", player.Name))
        end
    end)
end

-----------------------------------------------------------------------------
-- CLIENT-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsClient() then
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Creates or updates the health bar UI on the player's screen.
    function HealthManager.createOrUpdateHealthBar(current, max)
        -- This function is intentionally left blank to prevent the creation
        -- of the old, duplicate health bar. The new health bar is managed
        -- by UIManager.client.lua.
    end
end

return HealthManager
