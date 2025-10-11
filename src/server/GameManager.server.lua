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

-- #############################
-- ## World & Object Helpers  ##
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

    local selectedMapTemplate = mapsFolder:FindFirstChild("MurkyWaterFishbowl")

    if not selectedMapTemplate then
        warn("[GameManager] CRITICAL: Map 'MurkyWaterFishbowl' not found in ServerStorage/Maps folder! Please save your map there.")
        return nil
    end

    print(string.format("[GameManager] Loading map: %s", selectedMapTemplate.Name))
    currentMap = selectedMapTemplate:Clone()

    if not currentMap.PrimaryPart then
        local largestPart, largestSize = nil, 0
        for _, child in ipairs(currentMap:GetDescendants()) do
            if child:IsA("BasePart") then
                local size = child.Size.X * child.Size.Y * child.Size.Z
                if size > largestSize then
                    largestSize = size
                    largestPart = child
                end
            end
        end
        if largestPart then
            currentMap.PrimaryPart = largestPart
            print(string.format("[GameManager] Auto-assigned PrimaryPart for map %s to %s", currentMap.Name, largestPart.Name))
        end
    end

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

function cleanupVictoryGates()
    for _, part in ipairs(Workspace:GetChildren()) do
        if part.Name:match("VictoryGate") then
            part:Destroy()
        end
    end
    print("[GameManager] Cleaned up Victory Gates.")
end

function activateVictoryGates()
    print("[GameManager] Activating Victory Gates.")
    local activatedGates = {}
    for _, part in ipairs(Workspace:GetChildren()) do
        if part.Name:match("VictoryGate") then
            table.insert(activatedGates, part)
            part.Transparency = 0
            part.Material = Enum.Material.Neon
            part.BrickColor = BrickColor.new("Bright yellow")

            part.Touched:Connect(function(otherPart)
                local character = otherPart.Parent
                if not character then return end

                local player = Players:GetPlayerFromCharacter(character)
                if player and player.Team == survivorsTeam then
                    -- Mark the player as escaped
                    player.Team = nil
                    print(string.format("[GameManager] Survivor %s has escaped!", player.Name))

                    -- Make character invisible, non-collidable, and immobile
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Anchored = true
                    end
                    for _, p in ipairs(character:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.Transparency = 1
                            p.CanCollide = false
                        end
                    end
                end
            end)
        end
    end
    return activatedGates
end

function cleanupMachines()
    local machineFolder = Workspace:FindFirstChild("MiniGameMachines")
    if machineFolder then
        machineFolder:Destroy()
        print("[GameManager] Cleaned up machines.")
    end
end

function spawnMachines(mapModel)
    cleanupMachines()

    local assetsFolder = ServerStorage:FindFirstChild("Assets")
    if not assetsFolder then
        warn("[GameManager] Assets folder not found in ServerStorage. Cannot spawn machines.")
        return
    end

    local machineTemplate = assetsFolder:FindFirstChild("MachineTemplate")
    if not machineTemplate then
        warn("[GameManager] MachineTemplate not found in ServerStorage/Assets. Cannot spawn machines.")
        return
    end

    local machineFolder = Instance.new("Folder")
    machineFolder.Name = "MiniGameMachines"
    machineFolder.Parent = Workspace

    if not mapModel or not mapModel.PrimaryPart or not mapModel.PrimaryPart:IsA("BasePart") then
        warn("[GameManager] Cannot spawn machines: Map model is missing a valid PrimaryPart.")
        return
    end
    local mapBounds = mapModel.PrimaryPart
    local gameTypes = {"ButtonMash", "MemoryCheck", "MatchingGame"}

    for i = 1, CONFIG.MACHINES_TO_SPAWN do
        local machine = machineTemplate:Clone()
        machine.Name = "Machine" .. i

        if not machine.PrimaryPart then
            local largestPart, largestSize = nil, 0
            for _, child in ipairs(machine:GetDescendants()) do
                if child:IsA("BasePart") then
                    local size = child.Size.X * child.Size.Y * child.Size.Z
                    if size > largestSize then
                        largestSize = size
                        largestPart = child
                    end
                end
            end
            if largestPart then
                machine.PrimaryPart = largestPart
            end
        end

        local randomType = gameTypes[math.random(#gameTypes)]
        machine:SetAttribute("GameType", randomType)

        local randomX = mapBounds.Position.X + math.random(-mapBounds.Size.X / 2, mapBounds.Size.X / 2)
        local randomZ = mapBounds.Position.Z + math.random(-mapBounds.Size.Z / 2, mapBounds.Size.Z / 2)
        machine:SetPrimaryPartCFrame(CFrame.new(randomX, mapBounds.Position.Y + machine.PrimaryPart.Size.Y / 2, randomZ))

        machine.Parent = machineFolder
    end

    print(string.format("[GameManager] Spawned %d machines.", CONFIG.MACHINES_TO_SPAWN))

    -- Also spawn the inactive Victory Gates
    local mapCFrame, mapSize = mapModel:GetBoundingBox()
    local INSET_DISTANCE = 10 -- How many studs to move inward from the edge
    local RAYCAST_HEIGHT = 200 -- How high above the spawn point to start the raycast

    local function spawnGate(index, horizontalPosition)
        -- 1. Start raycast high above the inset point
        local rayOrigin = horizontalPosition + Vector3.new(0, RAYCAST_HEIGHT, 0)
        local rayDirection = Vector3.new(0, -1, 0) * (RAYCAST_HEIGHT * 2)

        -- 2. Perform the raycast to find the ground
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {mapModel}
        raycastParams.FilterType = Enum.RaycastFilterType.Include
        local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

        local groundPosition
        if raycastResult and raycastResult.Position then
            groundPosition = raycastResult.Position
            print(string.format("[GameManager] Raycast for Gate %d hit ground at: %s", index, tostring(groundPosition)))
        else
            -- Fallback: If raycast fails, use the center of the map's Y position
            groundPosition = Vector3.new(horizontalPosition.X, mapCFrame.Position.Y, horizontalPosition.Z)
            warn(string.format("[GameManager] Raycast failed for Gate %d. Using fallback Y position.", index))
        end

        local gate = Instance.new("Part")
        gate.Name = "VictoryGate" .. index
        gate.Size = Vector3.new(12, 15, 2)
        gate.Anchored = true
        gate.CanCollide = false
        gate.Transparency = 1 -- Initially invisible
        gate.Material = Enum.Material.Plastic
        gate.BrickColor = BrickColor.new("Black")
        -- Position the gate on the ground, adjusting for its own height
        gate.Position = groundPosition + Vector3.new(0, gate.Size.Y / 2, 0)
        gate.Parent = Workspace
    end

    local edge1, edge2
    local center = mapCFrame.Position
    -- Determine the longest axis to place the gates on
    if mapSize.X > mapSize.Z then
        -- Place on the left and right (X axis), inset by the specified distance
        local halfX = mapSize.X / 2 - INSET_DISTANCE
        edge1 = Vector3.new(center.X + halfX, center.Y, center.Z)
        edge2 = Vector3.new(center.X - halfX, center.Y, center.Z)
    else
        -- Place on the front and back (Z axis), inset by the specified distance
        local halfZ = mapSize.Z / 2 - INSET_DISTANCE
        edge1 = Vector3.new(center.X, center.Y, center.Z + halfZ)
        edge2 = Vector3.new(center.X, center.Y, center.Z - halfZ)
    end

    spawnGate(1, edge1)
    spawnGate(2, edge2)

    print("[GameManager] Spawned 2 inactive Victory Gates using inset and raycasting.")
end

-- #############################
-- ## State Machine Logic     ##
-- #############################

function enterWaiting()
    print("[GameManager] State -> Waiting")
    SimulatedPlayerManager.despawnSimulatedPlayers()
    cleanupCurrentLevel()
    cleanupMachines()
    cleanupVictoryGates()
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
    GameStateManager:SetNewRoundState(CONFIG.ROUND_DURATION, CONFIG.MACHINES_TO_SPAWN)
    stateTimer = CONFIG.ROUND_DURATION
    local loadedMap = loadRandomLevel()
    if not loadedMap then
        warn("[GameManager] CRITICAL: No map could be loaded. Returning to Waiting state.")
        gameState = "Waiting"
        enterWaiting()
        return
    end
    spawnMachines(loadedMap)
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

function enterEscape()
    print("[GameManager] State -> ESCAPE")
    local gates = activateVictoryGates()
    stateTimer = CONFIG.VICTORY_GATE_TIMER
    GameStateManager:SetTimer(stateTimer) -- Update the HUD timer

    -- DIAGNOSTIC: Wait 2 seconds to test race condition
    task.wait(2)

    -- Fire the new event to all survivors with the gate names
    local gateNames = {}
    for _, gate in ipairs(gates) do
        table.insert(gateNames, gate.Name)
    end

    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local escapeEvent = remotes:WaitForChild("EscapeSequenceStarted")
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Team == survivorsTeam then
            print("[GameManager-DEBUG] Firing EscapeSequenceStarted event for: " .. player.Name)
            escapeEvent:FireClient(player, gateNames)
        end
    end
end

function checkWinConditions()
    -- Check for machine repair victory first
    if GameStateManager:AreAllMachinesRepaired() then
        print("[GameManager] Win Condition: All machines repaired! Starting escape sequence.")
        return "SurvivorsWin_Escape"
    end

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
    GameStateManager:SetStateName(gameState)
    enterWaiting()
    while true do
        task.wait(1)
        if gameState == "Waiting" then
            if not manualStart and #Players:GetPlayers() >= CONFIG.MIN_PLAYERS then
                gameState = "Intermission"; GameStateManager:SetStateName("Intermission"); enterIntermission()
            end
        elseif gameState == "Intermission" then
            if not manualStart and #Players:GetPlayers() < CONFIG.MIN_PLAYERS then
                print("[GameManager] Player count dropped below minimum. Returning to Waiting state.")
                gameState = "Waiting"; GameStateManager:SetStateName("Waiting"); enterWaiting()
            else
                stateTimer = stateTimer - 1
                GameStateManager:SetTimer(stateTimer)
                if stateTimer <= 0 then
                    manualStart = false
                    gameState = "Playing"; GameStateManager:SetStateName("Playing"); enterPlaying()
                end
            end
        elseif gameState == "Playing" then
            stateTimer = stateTimer - 1
            GameStateManager:SetTimer(stateTimer)
            local winStatus = checkWinConditions()
            if winStatus == "SurvivorsWin_Escape" then
                gameState = "Escape"; GameStateManager:SetStateName("Escape"); enterEscape()
            elseif winStatus or stateTimer <= 0 then
                gameState = "PostRound"; GameStateManager:SetStateName("PostRound"); enterPostRound()
            end
        elseif gameState == "Escape" then
            stateTimer = stateTimer - 1
            GameStateManager:SetTimer(stateTimer)
            if stateTimer <= 0 then
                gameState = "PostRound"; GameStateManager:SetStateName("PostRound"); enterPostRound()
            end
        elseif gameState == "PostRound" then
            stateTimer = stateTimer - 1
            if stateTimer <= 0 then
                gameState = "Waiting"; GameStateManager:SetStateName("Waiting"); enterWaiting()
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
    GameStateManager:SetStateName("Waiting")
    enterWaiting()
end)

startRoundEvent.OnServerEvent:Connect(function(player)
    print(string.format("[GameManager] Manual start requested by %s.", player.Name))
    if gameState == "Waiting" then
        manualStart = true
        gameState = "Intermission"
        GameStateManager:SetStateName("Intermission")
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

-- Initialize all necessary manager modules that have listeners
StoreKeeperManager.initialize()
GameStateManager.initialize()

print("GameManager is running.")