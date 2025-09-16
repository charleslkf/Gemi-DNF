--[[
    KillerInteractionManager.server.lua
    by Jules

    This script manages all server-side interactions between Killers and Survivors,
    including hit detection, damage application, caging, and cooldowns.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Modules
local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
local CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))

-- Constants
local ATTACK_COOLDOWN = 5 -- seconds
local ATTACK_DAMAGE = 30
local CAGE_HEALTH_THRESHOLD = 50

-- State
local lastAttackTimes = {} -- { [Player]: tick() }

-- Main Logic
local function onCharacterTouched(killerPlayer, otherPart)
    -- Check if the killer is on cooldown
    local lastAttack = lastAttackTimes[killerPlayer]
    if lastAttack and (tick() - lastAttack < ATTACK_COOLDOWN) then
        return
    end

    -- Find the player associated with the part that was touched
    local otherPlayer = Players:GetPlayerFromCharacter(otherPart.Parent)
    if not otherPlayer or otherPlayer == killerPlayer then return end

    -- Check if the other player is a survivor
    if otherPlayer.Team and otherPlayer.Team.Name == "Survivors" then
        print(string.format("Interaction: %s hit %s.", killerPlayer.Name, otherPlayer.Name))

        -- Set the cooldown *before* applying damage
        lastAttackTimes[killerPlayer] = tick()

        -- Apply damage
        HealthManager.applyDamage(otherPlayer, ATTACK_DAMAGE)

        -- Check if the survivor should be caged
        local survivorHealth = HealthManager.getHealth(otherPlayer)
        if survivorHealth and survivorHealth <= CAGE_HEALTH_THRESHOLD then
            CagingManager.cagePlayer(otherPlayer)
        end
    end
end

local function setupCharacter(character, player)
    -- This function sets up the .Touched event for a character model.
    -- We connect it to every part to ensure good detection.
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Touched:Connect(function(otherPart)
                -- We only care about touches initiated by the Killer's character
                if player.Team and player.Team.Name == "Killers" then
                    onCharacterTouched(player, otherPart)
                end
            end)
        end
    end
end

local function onPlayerAdded(player)
    -- When a player's character spawns, set up the touch events
    player.CharacterAdded:Connect(function(character)
        setupCharacter(character, player)
    end)
    -- Also set it up for the character that might already exist
    if player.Character then
        setupCharacter(player.Character, player)
    end
end

-- Connect the logic for all current and future players
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

print("KillerInteractionManager is running.")
