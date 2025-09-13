--[[
    LobbyManager.server.lua
    by Jules (v5 - Definitive Fix)

    This script manages the game lobby, player assignments, and round starts.
    This version includes the definitive, most robust fix for the killer freeze bug.
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
        local spawnCFrame = spawnPoints[i % #spawnPoints + 1].CFrame + Vector3.new(0, 3, 0)

        local connection
        connection = player.CharacterAdded:Connect(function(character)
            connection:Disconnect()

            -- Use a coroutine to handle teleport and freeze without yielding the main spawn loop
            coroutine.wrap(function()
                -- Wait a frame to ensure all default character scripts have run, to avoid race conditions
                task.wait()

                character:SetPrimaryPartCFrame(spawnCFrame)

                if table.find(killers, player) then
                    print("Character added for killer: " .. player.Name .. ". Applying aggressive freeze.")
                    local humanoid = character:WaitForChild("Humanoid")
                    local hrp = character:WaitForChild("HumanoidRootPart")

                    local originalWalkSpeed = humanoid.WalkSpeed
                    local originalJumpPower = humanoid.JumpPower

                    hrp.Anchored = true
                    humanoid.WalkSpeed = 0
                    humanoid.JumpPower = 0

                    -- Unfreeze after delay
                    task.delay(CONFIG.KILLER_SPAWN_DELAY, function()
                        if humanoid.Parent then
                            print("Unfreezing " .. player.Name)
                            hrp.Anchored = false
                            humanoid.WalkSpeed = originalWalkSpeed
                            humanoid.JumpPower = originalJumpPower
                        end
                    end)
                end
            end)()
        end)

        player:LoadCharacter()
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

            local playersInRound = Players:GetPlayers()
            local numPlayers = #playersInRound
            local killers, survivors = {}, {}

            if CONFIG.TESTING_MODE and numPlayers < CONFIG.MIN_PLAYERS then
                killers = { playersInRound[1] }
            else
                local shuffledPlayers = shuffle(playersInRound)
                local numInitialKillers = 1; if numPlayers >= 9 and numPlayers <= 12 then numInitialKillers = 1 elseif numPlayers == 13 then numInitialKillers = 3 end
                for i = 1, numInitialKillers do table.insert(killers, shuffledPlayers[i]) end
                for i = numInitialKillers + 1, numPlayers do table.insert(survivors, shuffledPlayers[i]) end
                if numPlayers >= 9 and numPlayers <= 12 then
                    local secondKiller = LobbyManager.handleGambleCondition(killers[1], survivors)
                    if secondKiller then
                        table.insert(killers, secondKiller)
                        for i, v in ipairs(survivors) do if v == secondKiller then table.remove(survivors, i); break end end
                    end
                end
            end

            for _, player in ipairs(playersInRound) do
                if table.find(killers, player) then player.Team = killersTeam else player.Team = survivorsTeam end
            end
            print(string.format("Status: Teams assigned. %d Killer(s), %d Survivor(s).", #killers, #survivors))

            print("Status: Round in progress!")
            LobbyManager.spawnPlayers(killers, survivors)
            wait(CONFIG.ROUND_DURATION)

            print("Status: Round over! Returning to lobby...")
            for _, player in ipairs(Players:GetPlayers()) do
                if player and player.Parent == Players then
                    player.Team = nil; player.RespawnLocation = lobbySpawn; player:LoadCharacter()
                end
            end
            wait(5)
        end)
        wait(1)
    end
end

LobbyManager.runGameLoop()

return LobbyManager
