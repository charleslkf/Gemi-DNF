--[[
    LobbyManager.server.lua
    by Jules (v9 - Win Condition Logic)

    This script manages the game lobby and round lifecycle using a non-blocking state machine.
    The main loop acts as a heartbeat, processing states and timers.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
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
    ROUND_DURATION = 120,
    POST_ROUND_DURATION = 5,
    KILLER_SPAWN_DELAY = 5,
    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
    MIN_PLAYERS = 5,
}

-- Teams
local killersTeam = Teams:FindFirstChild("Killers") or Instance.new("Team", Teams); killersTeam.Name = "Killers"; killersTeam.TeamColor = BrickColor.new("Really red")
local survivorsTeam = Teams:FindFirstChild("Survivors") or Instance.new("Team", Teams); survivorsTeam.Name = "Survivors"; survivorsTeam.TeamColor = BrickColor.new("Bright blue")

-- World Setup
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn") or Instance.new("SpawnLocation", Workspace); lobbySpawn.Name = "LobbySpawn"; lobbySpawn.Position = CONFIG.LOBBY_SPAWN_POSITION; lobbySpawn.Anchored = true; lobbySpawn.Neutral = true

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetRoundEvent = remotes:WaitForChild("ResetRoundRequest")
local startRoundEvent = remotes:WaitForChild("StartRoundRequest")
local testDamageEvent = remotes:WaitForChild("TestDamageRequest")
local testCageEvent = remotes:WaitForChild("TestCageRequest")
local testAddItemEvent = remotes:WaitForChild("TestAddItemRequest")

-- Game State
local gameState = "Waiting"
local stateTimer = 0
local currentLevel = 0
local currentKillers = {}
local currentSurvivors = {}

-- Forward declarations for state functions
local enterWaiting, enterIntermission, enterPlaying, enterPostRound, checkWinConditions

-- Helper Functions
local function resetPlayer(player)
    if not player or not player.Parent then return end
    player.Team = nil
    player.RespawnLocation = lobbySpawn
    player:LoadCharacter()
end

local function spawnPlayerCharacter(player, isKiller)
    local conn
    conn = player.CharacterAdded:Connect(function(character)
        if conn then conn:Disconnect(); conn = nil end
        task.defer(function()
            if not character or not character.Parent then return end
            local spawnPos = Vector3.new(math.random(-50, 50), 5, math.random(-50, 50))
            character:SetPrimaryPartCFrame(CFrame.new(spawnPos))
            if isKiller then
                print("Freezing killer: " .. player.Name)
                local hrp = character:WaitForChild("HumanoidRootPart")
                hrp.Anchored = true
                task.delay(CONFIG.KILLER_SPAWN_DELAY, function()
                    if hrp and hrp.Parent then
                        print("Unfreezing " .. player.Name)
                        hrp.Anchored = false
                    end
                end)
            end
        end)
    end)
    player:LoadCharacter()
end

-- State Entry Functions (Non-Blocking)
function enterWaiting()
    print("Status: Entering Waiting State.")
    SimulatedPlayerManager.despawnSimulatedPlayers() -- Despawn bots at the end of a round
    MapManager.cleanup()
    StoreKeeperManager.stopManaging()
    CoinStashManager.cleanupStashes()
    table.clear(currentKillers)
    table.clear(currentSurvivors)
    for _, player in ipairs(Players:GetPlayers()) do
        resetPlayer(player)
    end
end

function enterIntermission()
    print(string.format("Status: Intermission starting! Round begins in %d seconds.", CONFIG.INTERMISSION_DURATION))
    stateTimer = CONFIG.INTERMISSION_DURATION
end

function enterPlaying()
    currentLevel = currentLevel + 1
    GameStateManager:SetNewRoundState(CONFIG.ROUND_DURATION)
    print(string.format("Status: Starting Round! (Level %d)", currentLevel))
    stateTimer = CONFIG.ROUND_DURATION
    MapManager.generate()
    StoreKeeperManager.startManaging(currentLevel)
    CoinStashManager.spawnStashes()

    -- Spawn bots if the number of real players is below the minimum.
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
        -- Assign one real player as the killer
        local killerIndex = math.random(#realPlayers)
        local killerPlayer = realPlayers[killerIndex]
        killerPlayer.Team = killersTeam
        table.insert(currentKillers, killerPlayer)

        -- Create or reset the Kills leaderstat for the killer
        local leaderstats = killerPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local killsStat = leaderstats:FindFirstChild("Kills")
            if killsStat then
                killsStat.Value = 0
            else
                killsStat = Instance.new("IntValue")
                killsStat.Name = "Kills"
                killsStat.Value = 0
                killsStat.Parent = leaderstats
            end
        end

        -- Assign all other real players as survivors
        for i, player in ipairs(realPlayers) do
            if i ~= killerIndex then
                player.Team = survivorsTeam
                table.insert(currentSurvivors, player)
            end
        end
    end

    -- Add all bots to the survivor list
    for _, bot in ipairs(spawnedBots) do
        table.insert(currentSurvivors, bot)
    end

    print(string.format("Status: Teams assigned. %d Killer(s), %d Survivor(s) (including %d bots).", #currentKillers, #currentSurvivors, #spawnedBots))

    -- Reset LevelCoins for all real players
    for _, player in ipairs(realPlayers) do
        local leaderstats = player:FindFirstChild("leaderstats")
        local levelCoins = leaderstats and leaderstats:FindFirstChild("LevelCoins")
        if levelCoins then
            levelCoins.Value = 0
        end
    end

    -- Spawn characters for real players
    for _, player in ipairs(realPlayers) do
        local isKiller = (player.Team == killersTeam)
        spawnPlayerCharacter(player, isKiller)
        HealthManager.initializeHealth(player)
        InventoryManager.initializeInventory(player)
    end
end

function enterPostRound()
    print("Status: Round Over!")
    stateTimer = CONFIG.POST_ROUND_DURATION
end

function checkWinConditions()
    -- Count players who are still in the game and on their assigned team
    local activeSurvivors = 0
    for _, entity in ipairs(currentSurvivors) do
        -- Check if the entity is a real player or a bot
        if entity:IsA("Player") then
            -- It's a real player, check their team
            if entity.Parent and entity.Team == survivorsTeam then
                activeSurvivors = activeSurvivors + 1
            end
        else
            -- It's a bot model, just check if it's still in the workspace
            if entity.Parent then
                activeSurvivors = activeSurvivors + 1
            end
        end
    end

    local activeKillers = 0
    for _, killer in ipairs(currentKillers) do
        if killer.Parent and killer.Team == killersTeam then
            activeKillers = activeKillers + 1
        end
    end

    -- Killer win condition: no active survivors remain
    if #currentSurvivors > 0 and activeSurvivors == 0 then
        print("Win Condition: All survivors eliminated. Killers win!")
        return true
    end

    -- Survivor win condition: no active killers remain
    if #currentKillers > 0 and activeKillers == 0 then
        print("Win Condition: All killers eliminated or left. Survivors win!")
        return true
    end

    return false
end

-- Main Game Loop (Heartbeat)
task.spawn(function()
    enterWaiting() -- Initial setup
    while true do
        task.wait(1)

        if gameState == "Intermission" then
            stateTimer = stateTimer - 1
            GameStateManager:SetTimer(stateTimer)
            print(string.format("Intermission: %d", stateTimer))
            if stateTimer <= 0 then
                gameState = "Playing"; enterPlaying()
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

-- Event Listeners
resetRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Soft reset requested by %s. Forcing return to Waiting state.", player.Name))
    gameState = "Waiting"; enterWaiting()
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        gameState = "Intermission"; enterIntermission()
    end
end)

testDamageEvent.OnServerEvent:Connect(function(player)
    if gameState == "Playing" then
        HealthManager.applyDamage(player, 10)
    end
end)

testCageEvent.OnServerEvent:Connect(function(player)
    if gameState == "Playing" then
        local currentHealth = HealthManager.getHealth(player)
        if currentHealth and currentHealth > 50 then
            local damageToApply = currentHealth - 40
            HealthManager.applyDamage(player, damageToApply)
        end

        -- A small delay to ensure health update processes before caging
        task.wait(0.1)
        print(string.format("Status: Caging %s for test.", player.Name))
        CagingManager.cagePlayer(player)
    end
end)

testAddItemEvent.OnServerEvent:Connect(function(player, itemName)
    if gameState == "Playing" then
        print(string.format("Status: Giving item '%s' to %s.", itemName, player.Name))
        InventoryManager.addItem(player, itemName)
    end
end)

StoreKeeperManager.initialize()
GameStateManager.initialize()

-- Player Stats Setup
local function setupPlayerStats(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local levelCoins = Instance.new("IntValue")
    levelCoins.Name = "LevelCoins"
    levelCoins.Value = 0
    levelCoins.Parent = leaderstats

    local gameCoins = Instance.new("IntValue")
    gameCoins.Name = "GameCoins"
    gameCoins.Value = 0
    gameCoins.Parent = leaderstats

    print(string.format("Initialized stats for %s", player.Name))
end

Players.PlayerAdded:Connect(setupPlayerStats)
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayerStats(player)
end

print("LobbyManager (v9) is running.")
