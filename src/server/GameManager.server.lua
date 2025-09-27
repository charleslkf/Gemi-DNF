--[[
    GameManager.server.lua (Consolidated)

    The authoritative "brain" of the game. This script manages the game's state,
    map loading, and player spawning to be fully self-contained.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
local CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
local InventoryManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("InventoryManager"))
local SimulatedPlayerManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("SimulatedPlayerManager"))
local StoreKeeperManager = require(ServerScriptService:WaitForChild("StoreKeeperManager"))
local CoinStashManager = require(ServerScriptService:WaitForChild("CoinStashManager"))
local GameStateManager = require(ServerScriptService:WaitForChild("GameStateManager"))

-- Configuration
local CONFIG = {
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 180,
    POST_ROUND_DURATION = 5,
    KILLER_SPAWN_DELAY = 5,
    MIN_PLAYERS = 5,
    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
}

-- Teams
local killersTeam = Teams:FindFirstChild("Killers") or Instance.new("Team", Teams); killersTeam.Name = "Killers"; killersTeam.TeamColor = BrickColor.new("Really red")
local survivorsTeam = Teams:FindFirstChild("Survivors") or Instance.new("Team", Teams); survivorsTeam.Name = "Survivors"; survivorsTeam.TeamColor = BrickColor.new("Bright blue")

-- World/Lobby Setup
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn") or Instance.new("SpawnLocation", Workspace)
lobbySpawn.Name = "LobbySpawn"
lobbySpawn.Position = CONFIG.LOBBY_SPAWN_POSITION
lobbySpawn.Anchored = true
lobbySpawn.Neutral = true

local mapsFolder = ServerStorage:FindFirstChild("Maps")
if not mapsFolder then
    mapsFolder = Instance.new("Folder", ServerStorage)
    mapsFolder.Name = "Maps"
    print("[GameManager] Created Maps folder in ServerStorage. Please add map models to it.")
end

-- Game State
local gameState = "Waiting"
local stateTimer = 0
local currentLevel = 0
local currentKillers = {}
local currentSurvivors = {}
local manualStart = false
local currentMap = nil

-- Forward declarations
local enterWaiting, enterIntermission, enterPlaying, enterPostRound, checkWinConditions
local teleportToLobby, spawnPlayerInMap
local loadRandomLevel, cleanupCurrentLevel

-- #############################
-- ## World & Lobby Helpers   ##
-- #############################

function cleanupCurrentLevel()
    if currentMap and currentMap.Parent then
        currentMap:Destroy()
        print("[GameManager] Current map cleaned up.")
    end
    currentMap = nil
end

function loadRandomLevel()
    cleanupCurrentLevel()
    local availableMaps = mapsFolder:GetChildren()
    if #availableMaps == 0 then
        warn("[GameManager] No maps found in ServerStorage/Maps folder!")
        return nil
    end
    local randomIndex = math.random(#availableMaps)
    local selectedMapTemplate = availableMaps[randomIndex]
    print(string.format("[GameManager] Loading map: %s", selectedMapTemplate.Name))
    currentMap = selectedMapTemplate:Clone()
    currentMap.Parent = Workspace
    return currentMap
end

function teleportToLobby(player)
    if not player or not player.Parent then return end
    player.Team = nil
    player.RespawnLocation = lobbySpawn
    player:LoadCharacter()
    print(string.format("[GameManager] Teleported %s to lobby.", player.Name))
end

function spawnPlayerInMap(player, isKiller)
    local conn
    conn = player.CharacterAdded:Connect(function(character)
        if conn then conn:Disconnect(); conn = nil end
        task.defer(function()
            if not character or not character.Parent then return end
            local spawnPos = Vector3.new(math.random(-50, 50), 5, math.random(-50, 50))
            character:SetPrimaryPartCFrame(CFrame.new(spawnPos))
            if isKiller then
                print("[GameManager] Freezing killer: " .. player.Name)
                local hrp = character:WaitForChild("HumanoidRootPart")
                hrp.Anchored = true
                task.delay(CONFIG.KILLER_SPAWN_DELAY, function()
                    if hrp and hrp.Parent then
                        print("[GameManager] Unfreezing " .. player.Name)
                        hrp.Anchored = false
                    end
                end)
            end
        end)
    end)
    player:LoadCharacter()
end

-- #############################
-- ## State Machine Logic     ##
-- #############################

function enterWaiting()
    print("[GameManager] State -> Waiting")
    SimulatedPlayerManager.despawnSimulatedPlayers()
    cleanupCurrentLevel()
    StoreKeeperManager.stopManaging()
    CoinStashManager.cleanupStashes()
    table.clear(currentKillers)
    table.clear(currentSurvivors)
    for _, player in ipairs(Players:GetPlayers()) do
        teleportToLobby(player)
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
    local loadedMap = loadRandomLevel()
    if not loadedMap then
        warn("[GameManager] CRITICAL: No map could be loaded. Returning to Waiting state.")
        gameState = "Waiting"
        enterWaiting()
        return
    end
    StoreKeeperManager.startManaging(currentLevel)
    CoinStashManager.spawnStashes()
    CagingManager.resetAllCageCounts()

    local realPlayers = Players:GetPlayers()
    local botsToSpawn = 0
    if #realPlayers < CONFIG.MIN_PLAYERS then
        botsToSpawn = CONFIG.MIN_PLAYERS - #realPlayers
    end
    local spawnedBots = SimulatedPlayerManager.spawnSimulatedPlayers(botsToSpawn)

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

    for _, player in ipairs(realPlayers) do
        local isKiller = (player.Team == killersTeam)
        spawnPlayerInMap(player, isKiller)
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

task.spawn(function()
    enterWaiting()
    while true do
        task.wait(1)
        if gameState == "Waiting" then
            if not manualStart and #Players:GetPlayers() >= CONFIG.MIN_PLAYERS then
                gameState = "Intermission"; enterIntermission()
            end
        elseif gameState == "Intermission" then
            if not manualStart and #Players:GetPlayers() < CONFIG.MIN_PLAYERS then
                print("[GameManager] Player count dropped below minimum. Returning to Waiting state.")
                gameState = "Waiting"; enterWaiting()
            else
                stateTimer = stateTimer - 1
                GameStateManager:SetTimer(stateTimer)
                if stateTimer <= 0 then
                    manualStart = false
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

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetRoundEvent = remotes:WaitForChild("ResetRoundRequest")
local startRoundEvent = remotes:WaitForChild("StartRoundRequest")

resetRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("[GameManager] Soft reset requested by %s. Forcing return to Waiting state.", player.Name))
    gameState = "Waiting"
    enterWaiting()
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("[GameManager] Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        manualStart = true
        gameState = "Intermission"
        enterIntermission()
    end
end)

local function createTestAssets()
    if not Workspace:FindFirstChild("PlayableArea") then
        print("[GameManager] Creating PlayableArea part for bot navigation.")
        local playableArea = Instance.new("Part")
        playableArea.Name = "PlayableArea"
        playableArea.Size = Vector3.new(200, 1, 200)
        playableArea.Position = Vector3.new(0, 0.5, 0)
        playableArea.Anchored = true
        playableArea.Transparency = 1
        playableArea.CanCollide = false
        playableArea.Parent = Workspace
    end
    if not ReplicatedStorage:FindFirstChild("BotTemplate") then
        print("[GameManager] Creating R6 BotTemplate model.")
        local model = Instance.new("Model")
        model.Name = "BotTemplate"
        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = model
        local rootPart = Instance.new("Part")
        rootPart.Name = "HumanoidRootPart"
        rootPart.Size = Vector3.new(2, 2, 1)
        rootPart.CFrame = CFrame.new(0, 3, 0)
        rootPart.Parent = model
        model.PrimaryPart = rootPart
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 1)
        head.CFrame = CFrame.new(0, 4.5, 0)
        head.Parent = model
        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2, 1)
        torso.CFrame = CFrame.new(0, 2, 0)
        torso.Parent = model
        model.Parent = ReplicatedStorage
    end
end

createTestAssets()

print("GameManager is running.")