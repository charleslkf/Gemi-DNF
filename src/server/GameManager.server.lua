--[[
    GameManager.server.lua (Consolidated)

    The authoritative "brain" of the game. This script manages the game's state,
    map loading, and player spawning to be fully self-contained.
]]

-- Initialize the random number generator to ensure variety
math.randomseed(os.time())

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
local MapGenerator = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("MapGenerator"))

-- Generate the procedural map on server startup
MapGenerator.Generate()

-- Configuration
local CONFIG = {
	    INTERMISSION_DURATION = 15,
	    ROUND_DURATION = 180,
	    POST_ROUND_DURATION = 5,
	    KILLER_SPAWN_DELAY = 5,
	    MIN_PLAYERS = 5,
	    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
	    MACHINES_TO_SPAWN = 3,
	    VICTORY_GATE_TIMER = 30,
	    MACHINE_BONUS_TIME = 5,
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
local enterWaiting, enterIntermission, enterPlaying, enterPostRound, enterEscape, checkWinConditions
local teleportToLobby, spawnPlayerInMap
local loadRandomLevel, cleanupCurrentLevel, spawnMachines, cleanupMachines, cleanupVictoryGates, activateVictoryGates

--