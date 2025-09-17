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
    local ServerScriptService = game:GetService("ServerScriptService")
    local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
    -- Using a forward declaration for KillerAbilityManager to handle circular dependency if needed.
    local KillerAbilityManager

    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local playerCagedEvent = remotes:WaitForChild("PlayerCaged")
    local playerRescuedEvent = remotes:WaitForChild("PlayerRescued")

    local cageData = {} -- { [Player]: { cageCount: number, isTimerActive: boolean, killerWhoCaged: Player } }

    -- Forward declaration
    local eliminatePlayer

    -- Cages a player if their health is low enough.
    function CagingManager.cagePlayer(player, killer) -- killer can be nil
        local playerHealth = HealthManager.getHealth(player)
        if not playerHealth or playerHealth > CAGE_HEALTH_THRESHOLD then
            return
        end

        if not cageData[player] then
            cageData[player] = { cageCount = 0, isTimerActive = false, killerWhoCaged = nil }
        end

        -- A player who is already in a cage cannot be re-caged.
        if cageData[player].isTimerActive then return end

        cageData[player].cageCount += 1
        cageData[player].killerWhoCaged = killer -- Store the killer who initiated the cage
        local count = cageData[player].cageCount
        local duration = CAGE_TIMERS[count]

        print(string.format("Server: Caging %s (count: %d). Timer: %ds", player.Name, count, duration or 0))
        playerCagedEvent:FireAllClients(player, duration)

        if duration == 0 then
            eliminatePlayer(player, killer)
            return
        end

        cageData[player].isTimerActive = true
        task.spawn(function()
            task.wait(duration)
            if cageData[player] and cageData[player].isTimerActive then
                -- When the timer runs out, use the stored killer identity
                local originalKiller = cageData[player].killerWhoCaged
                eliminatePlayer(player, originalKiller)
            end
        end)
    end

    -- Returns true if a player is currently in a cage timer.
    function CagingManager.isCaged(player)
        return cageData[player] and cageData[player].isTimerActive
    end

    -- Rescues a player from their cage timer.
    function CagingManager.rescuePlayer(player)
        if not CagingManager.isCaged(player) then
            return
        end

        print(string.format("Server: %s has been rescued.", player.Name))
        cageData[player].isTimerActive = false
        cageData[player].killerWhoCaged = nil -- Clear the killer when rescued
        playerRescuedEvent:FireAllClients(player)
    end

    -- Eliminates a player, sending them back to the lobby.
    eliminatePlayer = function(player, killer) -- killer can be nil
        -- Lazily require KillerAbilityManager to prevent circular dependencies
        if not KillerAbilityManager then
            KillerAbilityManager = require(ServerScriptService:WaitForChild("KillerAbilityManager"))
        end

        print(string.format("Server: %s has been eliminated.", player.Name))

        if cageData[player] then
            cageData[player].isTimerActive = false
            cageData[player].killerWhoCaged = nil
        end

        if killer then
            print(string.format("Elimination credit goes to: %s", killer.Name))
            KillerAbilityManager.onElimination(killer)
        else
            print("Elimination occurred without a direct killer credit (e.g., cage timer expired).")
        end

        player.Team = nil
        local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
        if lobbySpawn then player.RespawnLocation = lobbySpawn end
        player:LoadCharacter()
    end
    -- Make eliminatePlayer accessible to other server scripts
    CagingManager.eliminatePlayer = eliminatePlayer

    -- Cleanup when a player leaves the game
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
    local activeCageUIs = {} -- { [Player]: { gui: BillboardGui, timerThread: thread } }

    -- Creates and manages a countdown UI over a caged player's head.
    function CagingManager.showCageUI(cagedPlayer, duration)
        if not cagedPlayer or not cagedPlayer.Character then return end

        CagingManager.hideCageUI(cagedPlayer) -- Clean up any existing UI first

        local head = cagedPlayer.Character:FindFirstChild("Head")
        if not head then return end

        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = CAGE_UI_NAME
        billboardGui.Size = UDim2.new(0, 200, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 3, 0)
        billboardGui.AlwaysOnTop = true

        local textLabel = Instance.new("TextLabel", billboardGui)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextScaled = true

        billboardGui.Parent = head

        local uiData = { gui = billboardGui, timerThread = nil }
        activeCageUIs[cagedPlayer] = uiData

        if duration == 0 then
            textLabel.Text = "ELIMINATED"
            task.wait(1)
            CagingManager.hideCageUI(cagedPlayer)
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

    -- Removes the cage UI from a player.
    function CagingManager.hideCageUI(cagedPlayer)
        if activeCageUIs[cagedPlayer] then
            local uiData = activeCageUIs[cagedPlayer]
            if uiData.timerThread then
                task.cancel(uiData.timerThread)
            end
            if uiData.gui then
                uiData.gui:Destroy()
            end
            activeCageUIs[cagedPlayer] = nil
        end
    end
end

return CagingManager
