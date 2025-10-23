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

    -- This table now uses the instance (Player or Model) as the key.
    local healthData = {}
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local healthChangedEvent = remotes:WaitForChild("HealthChanged")

    -- Server-to-server communication (Idempotent Initialization)
    local ServerScriptService = game:GetService("ServerScriptService")
    local bindables = ServerScriptService:FindFirstChild("Bindables")
    if not bindables then
        bindables = Instance.new("Folder")
        bindables.Name = "Bindables"
        bindables.Parent = ServerScriptService
    end

    local healthChangedInternalEvent = bindables:FindFirstChild("HealthChangedInternal_SERVER")
    if not healthChangedInternalEvent then
        healthChangedInternalEvent = Instance.new("BindableEvent")
        healthChangedInternalEvent.Name = "HealthChangedInternal_SERVER"
        healthChangedInternalEvent.Parent = bindables
    end


    ---
    -- Removes health data for a given entity.
    -- @param entity The Player or Model to clean up.
    function HealthManager.cleanupEntity(entity)
        if healthData[entity] then
            healthData[entity] = nil
            print(string.format("Server: Cleared health data for %s.", entity.Name))
        end
    end

    ---
    -- Initializes health for an entity (Player or Model) and informs clients.
    -- @param entity The Player or Model to initialize.
    -- @param maxHealth The maximum health value.
    function HealthManager.initializeHealth(entity, maxHealth)
        maxHealth = maxHealth or DEFAULT_MAX_HEALTH
        print(string.format("Server: Initializing health for %s to %d.", entity.Name, maxHealth))

        healthData[entity] = {
            current = maxHealth,
            max = maxHealth,
        }

        -- Tell all clients to create/update the health bar for this entity
        healthChangedEvent:FireAllClients(entity, maxHealth, maxHealth)
    end

    ---
    -- Returns the current health of an entity.
    -- @param entity The Player or Model to query.
    function HealthManager.getHealth(entity)
        if healthData[entity] then
            return healthData[entity].current
        end
        return nil
    end

    ---
    -- Applies damage to an entity and checks for elimination.
    -- @param entity The Player or Model to damage.
    -- @param amount The amount of damage to apply.
    -- @param damageDealer The Player who dealt the damage (can be nil).
    function HealthManager.applyDamage(entity, amount, damageDealer)
        if not CagingManager then
            CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
        end

        if not healthData[entity] then
            warn(string.format("Attempted to apply damage to %s, but they have no health data.", entity.Name))
            return
        end

        local data = healthData[entity]
        data.current = math.max(0, data.current - amount)

        print(string.format("Server: Applied %d damage to %s. New health: %d", amount, entity.Name, data.current))

        -- Tell all clients to update the health bar for this entity
        healthChangedEvent:FireAllClients(entity, data.current, data.max)
        -- Fire internal event for other server modules
        healthChangedInternalEvent:Fire(entity, data.current, data.max)

        -- Check for elimination
        if data.current <= 0 then
            CagingManager.eliminatePlayer(entity, damageDealer)
            -- Clear health data after elimination logic has run
            HealthManager.cleanupEntity(entity)
        end
    end

    ---
    -- Applies healing to an entity.
    -- @param entity The Player or Model to heal.
    -- @param amount The amount of health to restore.
    function HealthManager.applyHealing(entity, amount)
        if not healthData[entity] then
            warn(string.format("Attempted to apply healing to %s, but they have no health data.", entity.Name))
            return
        end

        local data = healthData[entity]
        data.current = math.min(data.max, data.current + amount)

        print(string.format("Server: Applied %d healing to %s. New health: %d", amount, entity.Name, data.current))

        -- Tell all clients to update the health bar for this entity
        healthChangedEvent:FireAllClients(entity, data.current, data.max)
        -- Fire internal event for other server modules
        healthChangedInternalEvent:Fire(entity, data.current, data.max)
    end

    -- Cleanup function for when a real player leaves
    Players.PlayerRemoving:Connect(function(player)
        HealthManager.cleanupEntity(player)
    end)
end

-----------------------------------------------------------------------------
-- CLIENT-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsClient() then
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Creates or updates a billboard health bar above a player's character.
    function HealthManager.createOrUpdateHealthBar(targetEntity, current, max)
        if not targetEntity then return end

        -- Handle both real players (Player) and bots (Model)
        local character
        if targetEntity:IsA("Player") then
            character = targetEntity.Character or targetEntity.CharacterAdded:Wait()
        else
            character = targetEntity -- It's a bot model
        end

        if not character then return end
        local head = character:WaitForChild("Head")

        -- Find or create the BillboardGui
        local billboardGui = head:FindFirstChild(HEALTH_BAR_UI_NAME)
        if not billboardGui then
            billboardGui = Instance.new("BillboardGui")
            billboardGui.Name = HEALTH_BAR_UI_NAME
            billboardGui.Size = UDim2.new(0, 150, 0, 40) -- Shorter and thinner
            billboardGui.StudsOffset = Vector3.new(0, 3, 0) -- Moved up to avoid overlap
            billboardGui.AlwaysOnTop = true
            billboardGui.Parent = head

            local background = Instance.new("Frame", billboardGui)
            background.Name = "Background"
            background.Size = UDim2.new(1, 0, 0, 15) -- Thinner bar
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
            text.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black text
            text.Font = Enum.Font.SourceSansBold
            text.TextSize = 15 -- Increased font size
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
