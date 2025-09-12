--[[
    LobbyManager.server.lua
    by Jules

    This script manages the game lobby, player assignments, and round starts
    for the Gemi-DNF game.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

-- Configuration
local CONFIG = {
    MIN_PLAYERS = 5,
    MAX_PLAYERS = 13,
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 10, -- Short for testing
    GAMBLE_TIMER = 10,
    KILLER_SPAWN_DELAY = 5,
    SPAWN_POINTS_COUNT = 20,
}

-- Teams
local killersTeam = Teams:FindFirstChild("Killers") or Instance.new("Team", Teams)
killersTeam.Name = "Killers"
killersTeam.TeamColor = BrickColor.new("Really red")

local survivorsTeam = Teams:FindFirstChild("Survivors") or Instance.new("Team", Teams)
survivorsTeam.Name = "Survivors"
survivorsTeam.TeamColor = BrickColor.new("Bright blue")

-- World Setup
local spawnsFolder = Workspace:FindFirstChild("Spawns") or Instance.new("Folder", Workspace)
spawnsFolder.Name = "Spawns"

local lobbySpawn = Workspace:FindFirstChild("LobbySpawn") or Instance.new("SpawnLocation", Workspace)
lobbySpawn.Name = "LobbySpawn"
lobbySpawn.Position = Vector3.new(0, 50, 0)
lobbySpawn.Size = Vector3.new(20, 1, 20)
lobbySpawn.Anchored = true
lobbySpawn.Neutral = true
lobbySpawn.AllowTeamChangeOnTouch = false

-- Game State & Remotes
local status = ReplicatedStorage:FindFirstChild("GameStatus") or Instance.new("StringValue", ReplicatedStorage)
status.Name = "GameStatus"

local remotes = ReplicatedStorage:FindFirstChild("GemiRemotes") or Instance.new("Folder", ReplicatedStorage)
remotes.Name = "GemiRemotes"

local gamblePromptEvent = remotes:FindFirstChild("GamblePrompt") or Instance.new("RemoteEvent", remotes)
gamblePromptEvent.Name = "GamblePrompt"

local gambleDecisionEvent = remotes:FindFirstChild("GambleDecision") or Instance.new("RemoteEvent", remotes)
gambleDecisionEvent.Name = "GambleDecision"


-- Module Table
local LobbyManager = {}

--[[
    Shuffles a table in-place using the Fisher-Yates algorithm.
]]
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--[[
    Creates a set of spawn points for the round.
]]
local function createSpawnPoints(amount)
    spawnsFolder:ClearAllChildren()
    for i = 1, amount do
        local spawnPoint = Instance.new("Part", spawnsFolder)
        spawnPoint.Name = "SpawnPoint" .. i
        spawnPoint.Size = Vector3.new(4, 1, 4)
        spawnPoint.Position = Vector3.new(math.random(-50, 50), 5, math.random(-50, 50))
        spawnPoint.Anchored = true
        spawnPoint.CanCollide = false
        spawnPoint.Transparency = 1
    end
    print(string.format("Created %d spawn points.", amount))
end

--[[
    Handles the "Gamble Condition" for the initial killer.
    This function fires a RemoteEvent to the killer's client and yields
    until a choice is made or the timer runs out. It uses a BindableEvent
    to signal completion from either the player's response or the timeout.
]]
function LobbyManager.handleGambleCondition(initialKiller, survivors)
    local choiceMade = Instance.new("BindableEvent")
    local secondKiller = nil
    gamblePromptEvent:FireClient(initialKiller, survivors)
    status.Value = string.format("%s is choosing a partner...", initialKiller.Name)
    local connection
    connection = gambleDecisionEvent.OnServerEvent:Connect(function(player, chosenPlayer)
        if player == initialKiller then
            if chosenPlayer == "SOLO" then
                secondKiller = nil
                if choiceMade.Parent then choiceMade:Fire() end
            elseif chosenPlayer and table.find(survivors, chosenPlayer) then
                secondKiller = chosenPlayer
                if choiceMade.Parent then choiceMade:Fire() end
            end
        end
    end)
    delay(CONFIG.GAMBLE_TIMER, function()
        if choiceMade.Parent then choiceMade:Fire() end
    end)
    choiceMade.Event:Wait()
    connection:Disconnect()
    choiceMade:Destroy()
    return secondKiller
end

--[[
    Spawns players at designated locations at the start of a round.
]]
function LobbyManager.spawnPlayers(killers, survivors)
    local spawnPoints = spawnsFolder:GetChildren()
    local shuffledSpawns = shuffle(spawnPoints)
    local allPlayers = {}
    for _, p in ipairs(killers) do table.insert(allPlayers, p) end
    for _, p in ipairs(survivors) do table.insert(allPlayers, p) end

    for i, player in ipairs(allPlayers) do
        player:LoadCharacter()
        local character = player.Character
        if character then
            local spawnCFrame = CFrame.new(0, 5, 0) -- Default spawn
            if shuffledSpawns[i] then
                spawnCFrame = shuffledSpawns[i].CFrame + Vector3.new(0, 3, 0)
            else
                warn("Not enough spawn points! Player " .. player.Name .. " spawned at origin.")
            end
            character:SetPrimaryPartCFrame(spawnCFrame)
        end
    end

    for _, killer in ipairs(killers) do
        local character = killer.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                humanoidRootPart.Anchored = true
                coroutine.wrap(function()
                    wait(CONFIG.KILLER_SPAWN_DELAY)
                    if humanoidRootPart.Parent then
                        humanoidRootPart.Anchored = false
                    end
                end)()
            end
        end
    end
end

--[[
    Creates a simple GUI for the player to see the game status.
]]
local function setupPlayerGui(player)
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("GameStatusGui") then return end
    local statusGui = Instance.new("ScreenGui", playerGui)
    statusGui.Name = "GameStatusGui"
    statusGui.ResetOnSpawn = false
    local statusLabel = Instance.new("TextLabel", statusGui)
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 50)
    statusLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    statusLabel.BackgroundTransparency = 0.2
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.TextSize = 24
    statusLabel.Text = status.Value
    local connection
    connection = status.Changed:Connect(function(newValue)
        if statusLabel.Parent then statusLabel.Text = newValue else connection:Disconnect() end
    end)
end

--[[
    The main game loop. This function runs indefinitely and orchestrates the
    entire game flow from intermission to round start, gameplay, and cleanup.
    It's wrapped in a pcall to prevent the entire script from crashing on an error.
]]
function LobbyManager.runGameLoop()
    createSpawnPoints(CONFIG.SPAWN_POINTS_COUNT)
    while true do
        pcall(function()
            status.Value = "Waiting for players..."
            while #Players:GetPlayers() < CONFIG.MIN_PLAYERS do
                status.Value = string.format("Waiting for players... (%d/%d)", #Players:GetPlayers(), CONFIG.MIN_PLAYERS)
                wait(1)
            end
            for i = CONFIG.INTERMISSION_DURATION, 1, -1 do
                if #Players:GetPlayers() < CONFIG.MIN_PLAYERS then return end
                status.Value = string.format("Round starting in %d...", i)
                wait(1)
            end

            -- TEAM ASSIGNMENT
            local playersInRound = Players:GetPlayers()
            local shuffledPlayers = shuffle(playersInRound)
            local numPlayers = #playersInRound
            local killers, survivors = {}, {}
            if numPlayers >= 5 and numPlayers <= 8 then table.insert(killers, shuffledPlayers[1])
            elseif numPlayers >= 9 and numPlayers <= 12 then
                local initialKiller = shuffledPlayers[1]
                table.insert(killers, initialKiller)
                local potentialTargets = {}
                for i = 2, numPlayers do table.insert(potentialTargets, shuffledPlayers[i]) end
                local secondKiller = LobbyManager.handleGambleCondition(initialKiller, potentialTargets)
                if secondKiller then table.insert(killers, secondKiller) end
            elseif numPlayers == 13 then
                for i = 1, 3 do table.insert(killers, shuffledPlayers[i]) end
            else table.insert(killers, shuffledPlayers[1]) end
            for _, player in ipairs(playersInRound) do
                if table.find(killers, player) then player.Team = killersTeam else player.Team = survivorsTeam; table.insert(survivors, player) end
            end

            -- SPAWN PLAYERS
            status.Value = "Round in progress!"
            LobbyManager.spawnPlayers(killers, survivors)
            wait(CONFIG.ROUND_DURATION)

            -- CLEANUP
            status.Value = "Round over! Returning to lobby..."
            for _, player in ipairs(Players:GetPlayers()) do
                if player then player.Team = nil; player:LoadCharacter() end
            end
            wait(5)
        end)
        wait(1)
    end
end

-- Connect events and start the loop
Players.PlayerAdded:Connect(setupPlayerGui)
for _, player in ipairs(Players:GetPlayers()) do setupPlayerGui(player) end
LobbyManager.runGameLoop()

return LobbyManager
