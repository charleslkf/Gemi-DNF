--[[
    LobbyManager.server.lua
    by Jules (v7 - State Machine with Spawning)

    This script manages the game lobby and round lifecycle using a state machine.
    It supports soft resets and manual round starts for testing.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local MapBuilder = require(ServerScriptService:WaitForChild("MapBuilder"))

-- Configuration
local CONFIG = {
    TESTING_MODE = true,
    MIN_PLAYERS = 5,
    MAX_PLAYERS = 13,
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 120,
    GAMBLE_TIMER = 10,
    KILLER_SPAWN_DELAY = 5,
    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
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
local gameRemotes = ReplicatedStorage:FindFirstChild("GemiRemotes") or Instance.new("Folder", ReplicatedStorage); gameRemotes.Name = "GemiRemotes"
local gamblePromptEvent = gameRemotes:FindFirstChild("GamblePrompt") or Instance.new("RemoteEvent", gameRemotes); gamblePromptEvent.Name = "GamblePrompt"
local gambleDecisionEvent = gameRemotes:FindFirstChild("GambleDecision") or Instance.new("RemoteEvent", gameRemotes); gambleDecisionEvent.Name = "GambleDecision"

-- Game State
local gameState = "Waiting"
local manualStartRequested = false

-- Helper Functions
local function shuffle(tbl) for i = #tbl, 2, -1 do local j = math.random(i); tbl[i], tbl[j] = tbl[j], tbl[i] end; return tbl end

local function resetPlayer(player)
    if not player or not player.Parent then return end
    player.Team = nil
    player.RespawnLocation = lobbySpawn
    player:LoadCharacter()
end

local function resetAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        resetPlayer(player)
    end
end

local function spawnPlayerCharacter(player, isKiller)
    local conn
    conn = player.CharacterAdded:Connect(function(character)
        conn:Disconnect()
        task.defer(function()
            if not character or not character.Parent then return end
            -- TODO: Get spawn points from MapBuilder instead of randomizing here.
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

-- State Handlers
local function handleWaitingState()
    print("Status: Waiting for players...")
    MapBuilder.cleanup()
    resetAllPlayers()
    manualStartRequested = false
    local minPlayersRequired = CONFIG.TESTING_MODE and 1 or CONFIG.MIN_PLAYERS
    while #Players:GetPlayers() < minPlayersRequired and not manualStartRequested do
        print(string.format("Status: Waiting for players... (%d/%d)", #Players:GetPlayers(), minPlayersRequired))
        task.wait(2)
        if gameState ~= "Waiting" then return end -- Exit if reset is called
    end
    if #Players:GetPlayers() >= minPlayersRequired or manualStartRequested then
        gameState = "Intermission"
    end
end

local function handleIntermissionState()
    print("Status: Intermission...")
    local minPlayersRequired = CONFIG.TESTING_MODE and 1 or CONFIG.MIN_PLAYERS
    for i = CONFIG.INTERMISSION_DURATION, 1, -1 do
        if #Players:GetPlayers() < minPlayersRequired then
            print("Status: Not enough players, returning to waiting.")
            gameState = "Waiting"
            return
        end
        if gameState ~= "Intermission" then return end -- Exit if reset is called
        print(string.format("Status: Round starting in %d...", i))
        task.wait(1)
    end
    gameState = "Playing"
end

local function handlePlayingState()
    print("Status: Starting Round...")
    MapBuilder.generate()

    local playersInRound = Players:GetPlayers()
    local numPlayers = #playersInRound
    local killers, survivors = {}, {}

    if CONFIG.TESTING_MODE and numPlayers < CONFIG.MIN_PLAYERS then
        killers = { playersInRound[1] }
        for i = 2, numPlayers do table.insert(survivors, playersInRound[i]) end
    else
        -- Full game logic
        print("Error: Full game logic not implemented in this refactor yet.")
        killers, survivors = {playersInRound[1]}, {}
        for i=2, #playersInRound do table.insert(survivors, playersInRound[i]) end
    end

    for _, p in ipairs(killers) do p.Team = killersTeam end
    for _, p in ipairs(survivors) do p.Team = survivorsTeam end
    print(string.format("Status: Teams assigned. %d Killer(s), %d Survivor(s).", #killers, #survivors))

    for _, player in ipairs(killers) do spawnPlayerCharacter(player, true) end
    for _, player in ipairs(survivors) do spawnPlayerCharacter(player, false) end

    print("Status: Round in progress!")
    for i = CONFIG.ROUND_DURATION, 1, -1 do
        if gameState ~= "Playing" then print("Status: Round interrupted."); return end
        task.wait(1)
    end
    gameState = "PostRound"
end

local function handlePostRoundState()
    print("Status: Round over! Returning to lobby...")
    task.wait(5)
    gameState = "Waiting"
end

-- Main Game Loop
task.spawn(function()
    while true do
        if gameState == "Waiting" then
            handleWaitingState()
        elseif gameState == "Intermission" then
            handleIntermissionState()
        elseif gameState == "Playing" then
            handlePlayingState()
        elseif gameState == "PostRound" then
            handlePostRoundState()
        end
        task.wait(0.1)
    end
end)

-- Event Listeners
resetRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Soft reset requested by %s.", player.Name))
    gameState = "Waiting"
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        manualStartRequested = true
    end
end)

print("LobbyManager (v7) is running.")
