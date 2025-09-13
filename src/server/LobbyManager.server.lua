--[[
    LobbyManager.server.lua
    by Jules (v4 - Refactored, No GUI)

    This script manages the game lobby, player assignments, and round starts.
    This version removes the out-of-scope GUI and focuses on core logic.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

-- Configuration
local CONFIG = {
    TESTING_MODE = true,
    MIN_PLAYERS = 5,
    MAX_PLAYERS = 13,
    INTERMISSION_DURATION = 15,
    ROUND_DURATION = 10,
    GAMBLE_TIMER = 10,
    KILLER_SPAWN_DELAY = 5,
    SPAWN_POINTS_COUNT = 20,
    LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0),
}

-- Teams
local killersTeam = Teams:FindFirstChild("Killers") or Instance.new("Team", Teams); killersTeam.Name = "Killers"; killersTeam.TeamColor = BrickColor.new("Really red")
local survivorsTeam = Teams:FindFirstChild("Survivors") or Instance.new("Team", Teams); survivorsTeam.Name = "Survivors"; survivorsTeam.TeamColor = BrickColor.new("Bright blue")

-- World Setup
local spawnsFolder = Workspace:FindFirstChild("Spawns") or Instance.new("Folder", Workspace); spawnsFolder.Name = "Spawns"
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn") or Instance.new("SpawnLocation", Workspace); lobbySpawn.Name = "LobbySpawn"; lobbySpawn.Position = CONFIG.LOBBY_SPAWN_POSITION; lobbySpawn.Anchored = true; lobbySpawn.Neutral = true

-- Remotes
local remotes = ReplicatedStorage:FindFirstChild("GemiRemotes") or Instance.new("Folder", ReplicatedStorage); remotes.Name = "GemiRemotes"
local gamblePromptEvent = remotes:FindFirstChild("GamblePrompt") or Instance.new("RemoteEvent", remotes); gamblePromptEvent.Name = "GamblePrompt"
local gambleDecisionEvent = remotes:FindFirstChild("GambleDecision") or Instance.new("RemoteEvent", remotes); gambleDecisionEvent.Name = "GambleDecision"

-- Module Table
local LobbyManager = {}

local function shuffle(tbl) for i = #tbl, 2, -1 do local j = math.random(i); tbl[i], tbl[j] = tbl[j], tbl[i] end; return tbl end

local function createSpawnPoints(amount)
    spawnsFolder:ClearAllChildren()
    for i = 1, amount do
        local spawnPoint = Instance.new("SpawnLocation", spawnsFolder)
        spawnPoint.Name = "SpawnPoint" .. i
        spawnPoint.Position = Vector3.new(math.random(-50, 50), 5, math.random(-50, 50))
        spawnPoint.Anchored = true; spawnPoint.Neutral = false; spawnPoint.Enabled = false
    end
end

function LobbyManager.handleGambleCondition(initialKiller, survivors)
    local choiceMade = Instance.new("BindableEvent")
    local secondKiller = nil
    gamblePromptEvent:FireClient(initialKiller, survivors)
    print(string.format("Status: %s is choosing a partner...", initialKiller.Name))
    local connection
    connection = gambleDecisionEvent.OnServerEvent:Connect(function(player, chosenPlayer)
        if player == initialKiller and choiceMade.Parent then
            if chosenPlayer == "SOLO" or not table.find(survivors, chosenPlayer) then
                secondKiller = nil
            else
                secondKiller = chosenPlayer
            end
            choiceMade:Fire()
        end
    end)
    delay(CONFIG.GAMBLE_TIMER, function()
        if choiceMade.Parent then choiceMade:Fire() end
    end)
    choiceMade.Event:Wait()
    connection:Disconnect(); choiceMade:Destroy()
    return secondKiller
end

function LobbyManager.spawnPlayers(killers, survivors)
    local spawnPoints = spawnsFolder:GetChildren()
    if #spawnPoints == 0 then warn("No spawn points found!"); return end
    local allPlayers = {}
    for _, p in ipairs(killers) do table.insert(allPlayers, p) end
    for _, p in ipairs(survivors) do table.insert(allPlayers, p) end

    for i, player in ipairs(allPlayers) do
        local spawn = spawnPoints[i % #spawnPoints + 1]
        player.RespawnLocation = spawn
        player:LoadCharacter()
    end

    for _, killer in ipairs(killers) do
        local char = killer.Character or killer.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        hrp.Anchored = true
        coroutine.wrap(function()
            wait(CONFIG.KILLER_SPAWN_DELAY)
            if hrp.Parent then hrp.Anchored = false end
        end)()
    end
end

function LobbyManager.runGameLoop()
    createSpawnPoints(CONFIG.SPAWN_POINTS_COUNT)
    while true do
        pcall(function()
            local minPlayersRequired = CONFIG.TESTING_MODE and 1 or CONFIG.MIN_PLAYERS
            print("Status: Waiting for players...")
            while #Players:GetPlayers() < minPlayersRequired do
                print(string.format("Status: Waiting for players... (%d/%d)", #Players:GetPlayers(), minPlayersRequired))
                wait(1)
            end
            for i = CONFIG.INTERMISSION_DURATION, 1, -1 do
                if #Players:GetPlayers() < minPlayersRequired then return end
                print(string.format("Status: Round starting in %d...", i))
                wait(1)
            end

            -- TEAM ASSIGNMENT
            local playersInRound = Players:GetPlayers()
            local numPlayers = #playersInRound
            local killers, survivors = {}, {}

            if CONFIG.TESTING_MODE and numPlayers < CONFIG.MIN_PLAYERS then
                print("Status: Testing mode with " .. numPlayers .. " player(s). Assigning as Killer.")
                killers = { playersInRound[1] }
            else
                -- Standard team assignment
                local shuffledPlayers = shuffle(playersInRound)
                local numInitialKillers = 1 -- Default

                if numPlayers >= 5 and numPlayers <= 8 then
                    numInitialKillers = 1
                elseif numPlayers >= 9 and numPlayers <= 12 then
                    numInitialKillers = 1 -- For the gamble
                elseif numPlayers == 13 then
                    numInitialKillers = 3
                end

                -- 1. Assign initial killers
                for i = 1, numInitialKillers do
                    table.insert(killers, shuffledPlayers[i])
                end

                -- 2. Assign initial survivors
                for i = numInitialKillers + 1, numPlayers do
                    table.insert(survivors, shuffledPlayers[i])
                end

                -- 3. Handle The Gamble Condition
                if numPlayers >= 9 and numPlayers <= 12 then
                    local initialKiller = killers[1]
                    local secondKiller = LobbyManager.handleGambleCondition(initialKiller, survivors)

                    if secondKiller then
                        -- Add to killers list
                        table.insert(killers, secondKiller)
                        -- REMOVE from survivors list
                        for i, survivor in ipairs(survivors) do
                            if survivor == secondKiller then
                                table.remove(survivors, i)
                                break
                            end
                        end
                    end
                end
            end

            -- 4. Set Player.Team property for everyone
            for _, player in ipairs(killers) do
                player.Team = killersTeam
            end
            for _, player in ipairs(survivors) do
                player.Team = survivorsTeam
            end
            print(string.format("Status: Teams assigned. %d Killer(s), %d Survivor(s).", #killers, #survivors))

            print("Status: Round in progress!")
            LobbyManager.spawnPlayers(killers, survivors)
            wait(CONFIG.ROUND_DURATION)

            print("Status: Round over! Returning to lobby...")
            for _, player in ipairs(Players:GetPlayers()) do
                if player then player.Team = nil; player.RespawnLocation = lobbySpawn; player:LoadCharacter() end
            end
            wait(5)
        end)
        wait(1)
    end
end

LobbyManager.runGameLoop()

return LobbyManager
