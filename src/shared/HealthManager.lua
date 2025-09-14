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

    -- Applies damage to a player and checks for elimination.
    function HealthManager.applyDamage(player, amount)
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
            print(string.format("Server: %s has been eliminated.", player.Name))
            healthData[player] = nil -- Clear health data
            player:LoadCharacter() -- Respawn the player
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
        local screenGui = playerGui:FindFirstChild(HEALTH_BAR_UI_NAME)
        if not screenGui then
            -- Create the GUI if it doesn't exist
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = HEALTH_BAR_UI_NAME
            screenGui.ResetOnSpawn = false
            screenGui.Parent = playerGui

            local background = Instance.new("Frame", screenGui)
            background.Name = "Background"
            background.Size = UDim2.new(0, 200, 0, 20)
            background.Position = UDim2.new(0.5, -100, 1, -80) -- Bottom center
            background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            background.BorderSizePixel = 1

            local bar = Instance.new("Frame", background)
            bar.Name = "Bar"
            bar.Size = UDim2.new(1, 0, 1, 0)
            bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green

            local text = Instance.new("TextLabel", background)
            text.Name = "HealthText"
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.fromRGB(0, 0, 0)
            text.Font = Enum.Font.SourceSansBold
            text.Text = ""
        end

        -- Update the bar's size and color
        local background = screenGui:WaitForChild("Background")
        local bar = background:WaitForChild("Bar")
        local text = background:WaitForChild("HealthText")

        local percentage = (current / max)
        bar.Size = UDim2.new(percentage, 0, 1, 0)

        -- Change color from green to red based on health
        bar.BackgroundColor3 = Color3.fromHSV(0.33 * percentage, 1, 1)

        text.Text = string.format("%d / %d", current, max)
    end
end

return HealthManager
