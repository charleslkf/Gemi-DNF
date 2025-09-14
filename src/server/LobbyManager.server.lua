--[[
    LobbyManager.server.lua
    by Jules (v8 - Non-Blocking State Machine)

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

-- Configuration
local CONFIG = {
    MIN_PLAYERS_TO_START_AUTO = 2, -- New: For automatic progression, not used by manual start
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 120,
    POST_ROUND_DURATION = 5,
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
local testDamageEvent = remotes:WaitForChild("TestDamageRequest")
local testCageEvent = remotes:WaitForChild("TestCageRequest")

-- Game State
local gameState = "Waiting"
local stateTimer = 0

-- Forward declarations for state functions
local enterWaiting, enterIntermission, enterPlaying, enterPostRound

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
        if conn then
            conn:Disconnect()
            conn = nil
        end
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
    MapManager.cleanup()
    for _, player in ipairs(Players:GetPlayers()) do
        resetPlayer(player)
    end
end

function enterIntermission()
    print(string.format("Status: Intermission starting! Round begins in %d seconds.", CONFIG.INTERMISSION_DURATION))
    stateTimer = CONFIG.INTERMISSION_DURATION
end

function enterPlaying()
    print("Status: Starting Round!")
    stateTimer = CONFIG.ROUND_DURATION
    MapManager.generate()

    local playersInRound = Players:GetPlayers()
    local killers, survivors = {}, {}
    -- Simplified team logic for now
    killers = { playersInRound[1] }
    for i = 2, #playersInRound do table.insert(survivors, playersInRound[i]) end

    for _, p in ipairs(killers) do p.Team = killersTeam end
    for _, p in ipairs(survivors) do p.Team = survivorsTeam end
    print(string.format("Status: Teams assigned. %d Killer(s), %d Survivor(s).", #killers, #survivors))

    for _, player in ipairs(killers) do
        spawnPlayerCharacter(player, true)
        HealthManager.initializeHealth(player)
    end
    for _, player in ipairs(survivors) do
        spawnPlayerCharacter(player, false)
        HealthManager.initializeHealth(player)
    end
end

function enterPostRound()
    print("Status: Round Over!")
    stateTimer = CONFIG.POST_ROUND_DURATION
end


-- Main Game Loop (Heartbeat)
task.spawn(function()
    enterWaiting() -- Initial setup
    while true do
        task.wait(1)

        if gameState == "Intermission" then
            stateTimer = stateTimer - 1
            print(string.format("Intermission: %d", stateTimer))
            if stateTimer <= 0 then
                gameState = "Playing"
                enterPlaying()
            end
        elseif gameState == "Playing" then
            stateTimer = stateTimer - 1
            if stateTimer <= 0 then
                gameState = "PostRound"
                enterPostRound()
            end
        elseif gameState == "PostRound" then
            stateTimer = stateTimer - 1
            if stateTimer <= 0 then
                gameState = "Waiting"
                enterWaiting()
            end
        end
    end
end)

-- Event Listeners
resetRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Soft reset requested by %s. Forcing return to Waiting state.", player.Name))
    gameState = "Waiting"
    enterWaiting()
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("Status: Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        gameState = "Intermission"
        enterIntermission()
    end
end)

testDamageEvent.OnServerEvent:Connect(function(player)
    if gameState == "Playing" then
        print(string.format("Status: Applying 10 test damage to %s.", player.Name))
        HealthManager.applyDamage(player, 10)
    else
        print(string.format("Status: Ignoring test damage request from %s (not in Playing state).", player.Name))
    end
end)

testCageEvent.OnServerEvent:Connect(function(player)
    if gameState == "Playing" then
        -- To test caging, we need to lower the player's health first.
        HealthManager.applyDamage(player, 60)
        print(string.format("Status: Caging %s for test.", player.Name))
        CagingManager.cagePlayer(player)
    else
        print(string.format("Status: Ignoring test cage request from %s (not in Playing state).", player.Name))
    end
end)

print("LobbyManager (v8) is running.")
