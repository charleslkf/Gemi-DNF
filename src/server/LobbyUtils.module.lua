--[[
    LobbyUtils.module.lua

    A utility module containing helper functions for managing the lobby
    and player spawning. This is called by the GameManager.
]]

-- Services
local Workspace = game:GetService("Workspace")

-- The Module
local LobbyUtils = {}

-- Constants
local LOBBY_SPAWN_POSITION = Vector3.new(0, 50, 0)

-- World Setup
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
if not lobbySpawn then
    lobbySpawn = Instance.new("SpawnLocation", Workspace)
    lobbySpawn.Name = "LobbySpawn"
    lobbySpawn.Position = LOBBY_SPAWN_POSITION
    lobbySpawn.Anchored = true
    lobbySpawn.Neutral = true
end

---
-- Resets a player's team and teleports them to the lobby spawn.
-- @param player The player to teleport.
function LobbyUtils.teleportToLobby(player)
    if not player or not player.Parent then return end
    player.Team = nil
    player.RespawnLocation = lobbySpawn
    player:LoadCharacter()
    print(string.format("[LobbyUtils] Teleported %s to lobby.", player.Name))
end

---
-- Spawns a player's character at a random position within the map area.
-- @param player The player whose character will be spawned.
-- @param isKiller A boolean indicating if the player is on the Killer team.
-- @param killerSpawnDelay The duration to freeze the killer after spawning.
function LobbyUtils.spawnPlayerInMap(player, isKiller, killerSpawnDelay)
    local conn
    conn = player.CharacterAdded:Connect(function(character)
        if conn then conn:Disconnect(); conn = nil end
        -- Use task.defer to avoid timing issues with character loading
        task.defer(function()
            if not character or not character.Parent then return end

            local spawnPos = Vector3.new(math.random(-50, 50), 5, math.random(-50, 50))
            character:SetPrimaryPartCFrame(CFrame.new(spawnPos))

            if isKiller then
                print("[LobbyUtils] Freezing killer: " .. player.Name)
                local hrp = character:WaitForChild("HumanoidRootPart")
                hrp.Anchored = true
                task.delay(killerSpawnDelay, function()
                    if hrp and hrp.Parent then
                        print("[LobbyUtils] Unfreezing " .. player.Name)
                        hrp.Anchored = false
                    end
                end)
            end
        end)
    end)
    player:LoadCharacter()
end

return LobbyUtils