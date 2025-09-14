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
    local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local playerCagedEvent = remotes:WaitForChild("PlayerCaged")
    local playerRescuedEvent = remotes:WaitForChild("PlayerRescued")

    local cageData = {} -- { [Player]: { cageCount: number, timerThread: thread } }

    -- Forward declaration
    local eliminatePlayer

    -- Cages a player if their health is low enough.
    function CagingManager.cagePlayer(player)
        local playerHealth = HealthManager.getHealth(player)
        if not playerHealth or playerHealth > CAGE_HEALTH_THRESHOLD then
            -- Optional: Add a warning if trying to cage a healthy player.
            return
        end

        -- Initialize data if it doesn't exist
        if not cageData[player] then
            cageData[player] = { cageCount = 0, timerThread = nil }
        end

        cageData[player].cageCount += 1
        local count = cageData[player].cageCount
        local duration = CAGE_TIMERS[count]

        print(string.format("Server: Caging %s (count: %d). Timer: %ds", player.Name, count, duration or 0))

        -- Fire event to all clients to show the UI
        playerCagedEvent:FireAllClients(player, duration)

        if duration == 0 then
            eliminatePlayer(player)
            return
        end

        -- Start a timer that leads to elimination
        local timerThread = task.spawn(function()
            task.wait(duration)
            -- Check if the thread was cancelled by a rescue
            if cageData[player] and cageData[player].timerThread == coroutine.running() then
                eliminatePlayer(player)
            end
        end)

        cageData[player].timerThread = timerThread
    end

    -- Rescues a player from their cage timer.
    function CagingManager.rescuePlayer(player)
        if not cageData[player] or not cageData[player].timerThread then
            return
        end

        print(string.format("Server: %s has been rescued.", player.Name))

        task.cancel(cageData[player].timerThread)
        cageData[player].timerThread = nil

        -- Fire event to all clients to hide the UI
        playerRescuedEvent:FireAllClients(player)
    end

    -- Eliminates a player, sending them back to the lobby.
    eliminatePlayer = function(player)
        print(string.format("Server: %s has been eliminated by the caging system.", player.Name))

        if cageData[player] then
            if cageData[player].timerThread then
                task.cancel(cageData[player].timerThread)
            end
            cageData[player] = nil -- Clear data on elimination
        end

        -- Respawn player in lobby (similar to LobbyManager's resetPlayer)
        player.Team = nil
        local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
        if lobbySpawn then player.RespawnLocation = lobbySpawn end
        player:LoadCharacter()
    end

    -- Cleanup when a player leaves the game
    Players.PlayerRemoving:Connect(function(player)
        if cageData[player] then
            if cageData[player].timerThread then
                task.cancel(cageData[player].timerThread)
            end
            cageData[player] = nil
        end
    end)
end

-----------------------------------------------------------------------------
-- CLIENT-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsClient() then
    local activeCageUIs = {} -- { [Player]: BillboardGui }

    -- Creates and manages a countdown UI over a caged player's head.
    function CagingManager.showCageUI(cagedPlayer, duration)
        if not cagedPlayer or not cagedPlayer.Character then return end

        -- Clean up any existing UI for this player first
        CagingManager.hideCageUI(cagedPlayer)

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
        activeCageUIs[cagedPlayer] = billboardGui

        -- Handle instant elimination case
        if duration == 0 then
            textLabel.Text = "ELIMINATED"
            task.wait(1)
            CagingManager.hideCageUI(cagedPlayer)
            return
        end

        -- Countdown loop
        local timerThread = task.spawn(function()
            for i = duration, 0, -1 do
                if not billboardGui.Parent then break end -- Stop if UI was removed
                textLabel.Text = string.format("RESCUE IN: %d", i)
                task.wait(1)
            end
        end)

        -- Store the thread so we can cancel it if rescued
        activeCageUIs[cagedPlayer].TimerThread = timerThread
    end

    -- Removes the cage UI from a player.
    function CagingManager.hideCageUI(cagedPlayer)
        if activeCageUIs[cagedPlayer] then
            if activeCageUIs[cagedPlayer].TimerThread then
                task.cancel(activeCageUIs[cagedPlayer].TimerThread)
            end
            activeCageUIs[cagedPlayer]:Destroy()
            activeCageUIs[cagedPlayer] = nil
        end
    end
end

return CagingManager
