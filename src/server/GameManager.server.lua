--[[
    GameManager.server.lua

    The authoritative "brain" of the game. This script manages the game's state
    through a formal state machine and orchestrates all other major systems.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

-- Modules
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
local CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
local InventoryManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("InventoryManager"))
local SimulatedPlayerManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("SimulatedPlayerManager"))
local StoreKeeperManager = require(ServerScriptService:WaitForChild("StoreKeeperManager"))
local CoinStashManager = require(ServerScriptService:WaitForChild("CoinStashManager"))
local GameStateManager = require(ServerScriptService:WaitForChild("GameStateManager"))
local LobbyUtils = require(ServerScriptService:WaitForChild("LobbyUtils"))

-- Configuration
local CONFIG = {
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 180,
    POST_ROUND_DURATION = 5,
    KILLER_SPAWN_DELAY = 5,
    MIN_PLAYERS = 5,
}

-- Teams
local killersTeam = Teams:FindFirstChild("Killers") or Instance.new("Team", Teams); killersTeam.Name = "Killers"; killersTeam.TeamColor = BrickColor.new("Really red")
local survivorsTeam = Teams:FindFirstChild("Survivors") or Instance.new("Team", Teams); survivorsTeam.Name = "Survivors"; survivorsTeam.TeamColor = BrickColor.new("Bright blue")

-- Game State
local gameState = "Waiting"
local stateTimer = 0
local currentLevel = 0
local currentKillers = {}
local currentSurvivors = {}

-- Forward declarations for state functions
local enterWaiting, enterIntermission, enterPlaying, enterPostRound, checkWinConditions

-- State Entry Functions
function enterWaiting()
    print("[GameManager] State -> Waiting")
    SimulatedPlayerManager.despawnSimulatedPlayers()
    MapManager.cleanup()
    StoreKeeperManager.stopManaging()
    CoinStashManager.cleanupStashes()
    table.clear(currentKillers)
    table.clear(currentSurvivors)
    for _, player in ipairs(Players:GetPlayers()) do
        LobbyUtils.teleportToLobby(player)
    end
end

function enterIntermission()
    print(string.format("[GameManager] State -> Intermission (%d seconds)", CONFIG.INTERMISSION_DURATION))
    stateTimer = CONFIG.INTERMISSION_DURATION
end

function enterPlaying()
    print("[GameManager] State -> Playing")
    currentLevel = currentLevel + 1
    GameStateManager:SetNewRoundState(CONFIG.ROUND_DURATION)
    stateTimer = CONFIG.ROUND_DURATION
    MapManager.generate()
    StoreKeeperManager.startManaging(currentLevel)
    CoinStashManager.spawnStashes()
    CagingManager.resetAllCageCounts()

    -- Spawn bots
    local realPlayers = Players:GetPlayers()
    local botsToSpawn = 0
    if #realPlayers < CONFIG.MIN_PLAYERS then
        botsToSpawn = CONFIG.MIN_PLAYERS - #realPlayers
    end
    local spawnedBots = SimulatedPlayerManager.spawnSimulatedPlayers(botsToSpawn)

    -- Team Assignment
    table.clear(currentKillers)
    table.clear(currentSurvivors)
    if #realPlayers > 0 then
        local killerIndex = math.random(#realPlayers)
        local killerPlayer = realPlayers[killerIndex]
        killerPlayer.Team = killersTeam
        table.insert(currentKillers, killerPlayer)
        local leaderstats = killerPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local killsStat = leaderstats:FindFirstChild("Kills")
            if killsStat then killsStat.Value = 0 else Instance.new("IntValue", leaderstats).Name = "Kills" end
        end
        for i, player in ipairs(realPlayers) do
            if i ~= killerIndex then
                player.Team = survivorsTeam
                table.insert(currentSurvivors, player)
            end
        end
    end
    for _, bot in ipairs(spawnedBots) do
        table.insert(currentSurvivors, bot)
    end
    print(string.format("[GameManager] Teams assigned: %d Killer(s), %d Survivor(s) (including %d bots).", #currentKillers, #currentSurvivors, #spawnedBots))

    -- Spawn and initialize all real players
    for _, player in ipairs(realPlayers) do
        local isKiller = (player.Team == killersTeam)
        LobbyUtils.spawnPlayerInMap(player, isKiller, CONFIG.KILLER_SPAWN_DELAY)
        HealthManager.initializeHealth(player)
        InventoryManager.initializeInventory(player)
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats and leaderstats:FindFirstChild("LevelCoins") then
            leaderstats.LevelCoins.Value = 0
        end
    end
end

function enterPostRound()
    print("[GameManager] State -> PostRound")
    stateTimer = CONFIG.POST_ROUND_DURATION
end

-- Win Condition Logic
function checkWinConditions()
    local activeSurvivors = 0
    for _, entity in ipairs(currentSurvivors) do
        if (entity:IsA("Player") and entity.Parent and entity.Team == survivorsTeam) or (not entity:IsA("Player") and entity.Parent) then
            activeSurvivors = activeSurvivors + 1
        end
    end

    local activeKillers = 0
    for _, killer in ipairs(currentKillers) do
        if killer.Parent and killer.Team == killersTeam then
            activeKillers = activeKillers + 1
        end
    end

    if #currentSurvivors > 0 and activeSurvivors == 0 then
        print("[GameManager] Win Condition: All survivors eliminated. Killers win!")
        return true
    end
    if #currentKillers > 0 and activeKillers == 0 then
        print("[GameManager] Win Condition: All killers eliminated or left. Survivors win!")
        return true
    end
    return false
end

-- Main Game Loop (Heartbeat)
task.spawn(function()
    enterWaiting() -- Initial setup
    while true do
        task.wait(1)
        if gameState == "Waiting" then
            if #Players:GetPlayers() >= CONFIG.MIN_PLAYERS then
                gameState = "Intermission"; enterIntermission()
            end
        elseif gameState == "Intermission" then
            if #Players:GetPlayers() < CONFIG.MIN_PLAYERS then
                print("[GameManager] Player count dropped below minimum. Returning to Waiting state.")
                gameState = "Waiting"; enterWaiting()
            else
                stateTimer = stateTimer - 1
                GameStateManager:SetTimer(stateTimer)
                if stateTimer <= 0 then
                    gameState = "Playing"; enterPlaying()
                end
            end
        elseif gameState == "Playing" then
            stateTimer = stateTimer - 1
            GameStateManager:SetTimer(stateTimer)
            if checkWinConditions() or stateTimer <= 0 then
                gameState = "PostRound"; enterPostRound()
            end
        elseif gameState == "PostRound" then
            stateTimer = stateTimer - 1
            if stateTimer <= 0 then
                gameState = "Waiting"; enterWaiting()
            end
        end
    end
end)

-- Player Stats Setup
local function setupPlayerStats(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    local levelCoins = Instance.new("IntValue", leaderstats); levelCoins.Name = "LevelCoins"
    local gameCoins = Instance.new("IntValue", leaderstats); gameCoins.Name = "GameCoins"
    print(string.format("[GameManager] Initialized stats for %s", player.Name))
end

Players.PlayerAdded:Connect(setupPlayerStats)
for _, player in ipairs(Players:GetPlayers()) do
    if not player:FindFirstChild("leaderstats") then
        setupPlayerStats(player)
    end
end

-- Event Listeners to allow manual control over the game loop
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetRoundEvent = remotes:WaitForChild("ResetRoundRequest")
local startRoundEvent = remotes:WaitForChild("StartRoundRequest")

resetRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("[GameManager] Soft reset requested by %s. Forcing return to Waiting state.", player.Name))
    gameState = "Waiting"
    enterWaiting()
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    -- The GDD specifies automatic start, but we will leave this here for testing.
    print(string.format("[GameManager] Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        gameState = "Intermission"
        enterIntermission()
    end
end)

print("GameManager is running.")