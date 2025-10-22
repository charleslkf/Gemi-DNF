--[[
    CagingManager.lua
    by Jules

    A self-contained module to manage the player caging, rescue, and elimination mechanics.
    This module has code paths for both the server (authoritative logic)
    and the client (UI management).
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Module Table
local CagingManager = {}

-- Constants
local CAGE_UI_NAME = "CageUi"
local CAGE_TIMERS = {
    [1] = 30, -- 1st time caged: 30 seconds
    [2] = 15, -- 2nd time caged: 15 seconds
    [3] = 0,  -- 3rd time caged: instant elimination
}
local CAGE_HEALTH_THRESHOLD = 50

-----------------------------------------------------------------------------
-- SERVER-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsServer() then
    -- Forward declaration for lazy loading
    local HealthManager
    local GameStateManager = require(game:GetService("ServerScriptService"):WaitForChild("GameStateManager"))

    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local playerCagedEvent = remotes:WaitForChild("PlayerCaged")
    local playerRescuedEvent = remotes:WaitForChild("PlayerRescued")
    local eliminationEvent = remotes:WaitForChild("EliminationEvent")

    -- Server-to-server communication (Idempotent Initialization)
    local ServerScriptService = game:GetService("ServerScriptService")
    local bindables = ServerScriptService:FindFirstChild("Bindables")
    if not bindables then
        bindables = Instance.new("Folder")
        bindables.Name = "Bindables"
        bindables.Parent = ServerScriptService
    end

    local playerRescuedInternalEvent = bindables:FindFirstChild("PlayerRescuedInternal")
    if not playerRescuedInternalEvent then
        playerRescuedInternalEvent = Instance.new("BindableEvent")
        playerRescuedInternalEvent.Name = "PlayerRescuedInternal"
        playerRescuedInternalEvent.Parent = bindables
    end

    -- This table now uses the instance (Player or Model) as the key.
    local cageData = {}

    -- Forward declaration
    local eliminatePlayer

    ---
    -- Resets the cage counts for all players at the start of a new round.
    function CagingManager.resetAllCageCounts()
        for entity, data in pairs(cageData) do
            data.cageCount = 0
        end
        print("Server: All player cage counts have been reset.")
    end

    ---
    -- Cages an entity if their health is low enough.
    -- @param entity The Player or Model to cage.
    -- @param killer The Player who initiated the cage.
    function CagingManager.cagePlayer(entity, killer)
        if not HealthManager then
            HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
        end

        local entityHealth = HealthManager.getHealth(entity)
        if not entityHealth or entityHealth > CAGE_HEALTH_THRESHOLD then
            return
        end

        if not cageData[entity] then
            cageData[entity] = { cageCount = 0, isTimerActive = false, killerWhoCaged = nil }
        end

        -- An entity who is already in a cage cannot be re-caged.
        if cageData[entity].isTimerActive then return end

        cageData[entity].cageCount += 1
        cageData[entity].killerWhoCaged = killer -- Store the killer who initiated the cage
        local count = cageData[entity].cageCount
        local duration = CAGE_TIMERS[count]

        print(string.format("Server: Caging %s (count: %d). Timer: %ds", entity.Name, count, duration or 0))
        playerCagedEvent:FireAllClients(entity, duration)

        if duration == 0 then
            eliminatePlayer(entity, killer)
            return
        end

        cageData[entity].isTimerActive = true
        task.spawn(function()
            task.wait(duration)
            if cageData[entity] and cageData[entity].isTimerActive then
                -- When the timer runs out, use the stored killer identity
                local originalKiller = cageData[entity].killerWhoCaged
                eliminatePlayer(entity, originalKiller)
            end
        end)
    end

    ---
    -- Returns true if an entity is currently in a cage timer.
    -- @param entity The Player or Model to query.
    function CagingManager.isCaged(entity)
        return cageData[entity] and cageData[entity].isTimerActive
    end

    ---
    -- Rescues an entity from their cage timer.
    -- @param entity The Player or Model to rescue.
    function CagingManager.rescuePlayer(entity)
        if not CagingManager.isCaged(entity) then
            return
        end

        print(string.format("Server: %s has been rescued.", entity.Name))
        cageData[entity].isTimerActive = false
        cageData[entity].killerWhoCaged = nil -- Clear the killer when rescued
        playerRescuedEvent:FireAllClients(entity)
        playerRescuedInternalEvent:Fire(entity)
    end

    ---
    -- Eliminates an entity, either respawning a player or destroying a bot.
    -- @param entity The Player or Model to eliminate.
    -- @param killer The Player who dealt the final blow.
    eliminatePlayer = function(entity, killer)
        print(string.format("Server: %s has been eliminated.", entity.Name))

        if cageData[entity] then
            cageData[entity].isTimerActive = false
            cageData[entity].killerWhoCaged = nil
            cageData[entity].cageCount = 0 -- Reset the cage count
        end

        -- Fire the elimination event for other systems to listen to
        eliminationEvent:Fire(entity, killer)

        -- Update the kill count on the HUD
        GameStateManager:IncrementKills()

        -- Check if the entity is a real player or a bot
        if entity:IsA("Player") then
            -- It's a real player, so respawn them in the lobby
            entity.Team = nil
            local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
            if lobbySpawn then entity.RespawnLocation = lobbySpawn end
            entity:LoadCharacter()
        else
            -- It's a bot (a Model), so just destroy it
            entity:Destroy()
        end
    end
    -- Make eliminatePlayer accessible to other server scripts
    CagingManager.eliminatePlayer = eliminatePlayer

    -- Cleanup when a real player leaves the game
    Players.PlayerRemoving:Connect(function(player)
        if cageData[player] then
            cageData[player] = nil
        end
    end)
end

-----------------------------------------------------------------------------
-- CLIENT-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsClient() then
    local activeCageUIs = {} -- { [Entity]: { gui: BillboardGui, timerThread: thread } }

    ---
    -- Removes the cage UI from an entity.
    -- @param entity The Player or Model to hide the UI for.
    function CagingManager.hideCageUI(entity)
        if activeCageUIs[entity] then
            local uiData = activeCageUIs[entity]
            if uiData.timerThread then
                task.cancel(uiData.timerThread)
            end
            if uiData.gui then
                uiData.gui:Destroy()
            end
            activeCageUIs[entity] = nil
        end
    end

    ---
    -- Creates and manages a countdown UI over a caged entity's head.
    -- @param entity The Player or Model to show the UI for.
    -- @param duration The countdown duration.
    function CagingManager.showCageUI(entity, duration)
        -- Handle both real players (Player) and bots (Model)
        local character
        if entity:IsA("Player") then
            character = entity.Character
        else
            character = entity -- It's a bot model
        end

        if not entity or not character then return end

        CagingManager.hideCageUI(entity) -- Clean up any existing UI first

        local head = character:FindFirstChild("Head")
        if not head then return end

        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = CAGE_UI_NAME
        billboardGui.Size = UDim2.new(0, 200, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 2.25, 0) -- Lowered to be below the health bar
        billboardGui.AlwaysOnTop = true

        local textLabel = Instance.new("TextLabel", billboardGui)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextScaled = true

        billboardGui.Parent = head

        local uiData = { gui = billboardGui, timerThread = nil }
        activeCageUIs[entity] = uiData

        if duration == 0 then
            textLabel.Text = "ELIMINATED"
            task.wait(1)
            CagingManager.hideCageUI(entity)
            return
        end

        uiData.timerThread = task.spawn(function()
            for i = duration, 0, -1 do
                if not uiData.gui or not uiData.gui.Parent then break end
                textLabel.Text = string.format("RESCUE IN: %d", i)
                task.wait(1)
            end
        end)
    end
end

return CagingManager
