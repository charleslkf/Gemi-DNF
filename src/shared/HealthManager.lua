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

        -- Tell all clients to create/update the health bar for this player
        healthChangedEvent:FireAllClients(player, maxHealth, maxHealth)
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

        -- Tell all clients to update the health bar for this player
        healthChangedEvent:FireAllClients(player, data.current, data.max)

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

    -- Creates or updates a billboard health bar above a player's character.
    function HealthManager.createOrUpdateHealthBar(targetPlayer, current, max)
        if not targetPlayer or not targetPlayer.Character then return end
        local character = targetPlayer.Character
        local head = character:FindFirstChild("Head")
        if not head then return end

        -- Find or create the BillboardGui
        local billboardGui = head:FindFirstChild(HEALTH_BAR_UI_NAME)
        if not billboardGui then
            billboardGui = Instance.new("BillboardGui")
            billboardGui.Name = HEALTH_BAR_UI_NAME
            billboardGui.Size = UDim2.new(0, 200, 0, 50)
            billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
            billboardGui.AlwaysOnTop = true
            billboardGui.Parent = head

            local background = Instance.new("Frame", billboardGui)
            background.Name = "Background"
            background.Size = UDim2.new(1, 0, 0, 20)
            background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            background.BorderSizePixel = 1

            local bar = Instance.new("Frame", background)
            bar.Name = "Bar"
            bar.Size = UDim2.new(1, 0, 1, 0)
            bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

            local text = Instance.new("TextLabel", background)
            text.Name = "HealthText"
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.fromRGB(255, 255, 255)
            text.Font = Enum.Font.SourceSansBold
        end

        -- Update the bar's size, color, and text
        local background = billboardGui:WaitForChild("Background")
        local bar = background:WaitForChild("Bar")
        local text = background:WaitForChild("HealthText")

        local percentage = 0
        if max > 0 then
            percentage = current / max
        end

        bar.Size = UDim2.new(percentage, 0, 1, 0)
        bar.BackgroundColor3 = Color3.fromHSV(0.33 * percentage, 1, 1)
        text.Text = string.format("%d / %d", current, max)
    end
end

return HealthManager
