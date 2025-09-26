--[[
    KillerInteractionManager.server.lua
    (New version by Jules - Remote Event based)

    This script manages all server-side interactions between Killers and Survivors,
    including hit detection, damage application, caging, and cooldowns.
    It listens for client-side requests and validates them before acting.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

-- Modules (forward declared for lazy loading)
local HealthManager
local CagingManager
local KillerAbilityManager

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")

-- Constants
local ATTACK_COOLDOWN = 5 -- seconds
local ATTACK_DAMAGE = 25
local CAGE_HEALTH_THRESHOLD = 50
local MAX_ATTACK_DISTANCE = 12 -- A little more than the client's 10 for latency tolerance

-- State
local lastAttackTimes = {} -- { [Player]: tick() }
local killersTeam = Teams:WaitForChild("Killers")
local survivorsTeam = Teams:WaitForChild("Survivors")

-- Main Handler for Attack Requests
-- Main Handler for Attack Requests. The target can be a Player object or a Model.
local function onAttackRequest(killerPlayer, targetCharacter)
    -- Lazily require all modules on first execution
    if not HealthManager then
        HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
        CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
        KillerAbilityManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("KillerAbilityManager"))
    end

    -- 1. VALIDATION AND SECURITY CHECKS

    -- Verify the killer and target exist and have characters
    if not killerPlayer or not killerPlayer.Character or not targetCharacter or not targetCharacter:FindFirstChild("Humanoid") then
        return
    end

    -- Determine if the target is a real player or a bot
    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if targetPlayer then
        -- Target is a real player, validate their team
        if targetPlayer.Team == killersTeam then
            return -- Killers can't attack other killers
        end
    elseif not targetCharacter.Name:match("^Bot") then
        -- Target is not a player and not a bot, so it's invalid
        return
    end

    -- Verify the killer is not on cooldown
    local lastAttack = lastAttackTimes[killerPlayer]
    if lastAttack and (tick() - lastAttack < ATTACK_COOLDOWN) then
        print(string.format("[InteractionManager] Attack blocked: %s is on cooldown.", killerPlayer.Name))
        return
    end

    -- Verify distance again on the server to prevent exploits
    local distance = (killerPlayer.Character.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    if distance > MAX_ATTACK_DISTANCE then
        print(string.format("[InteractionManager] Attack blocked: %s is too far from %s (%.1f studs).", killerPlayer.Name, targetCharacter.Name, distance))
        return
    end

    -- The "target entity" can be either a Player object or a bot's Model.
    -- Other modules will need to be updated to handle this polymorphism.
    local targetEntity = targetPlayer or targetCharacter

    -- Verify the target is not already caged
    if CagingManager.isCaged(targetEntity) then
        print(string.format("[InteractionManager] Attack blocked: %s is already caged.", targetCharacter.Name))
        return
    end

    -- 2. APPLY GAME LOGIC

    print(string.format("[InteractionManager] Attack validated: %s hit %s.", killerPlayer.Name, targetCharacter.Name))

    -- Set the cooldown *before* applying damage
    lastAttackTimes[killerPlayer] = tick()

    -- Check if the killer's ultimate is active
    if KillerAbilityManager.isUltimateActive(killerPlayer) then
        -- Perform an instant elimination
        KillerAbilityManager.performUltimateKill(targetEntity, killerPlayer)
    else
        -- Apply normal damage, passing the killerPlayer as the damageDealer
        HealthManager.applyDamage(targetEntity, ATTACK_DAMAGE, killerPlayer)

        -- Check if the survivor/bot should be caged (only for normal attacks)
        local targetHealth = HealthManager.getHealth(targetEntity)
        if targetHealth and targetHealth <= CAGE_HEALTH_THRESHOLD then
            print(string.format("[InteractionManager] Health is %d, attempting to cage %s.", targetHealth, targetCharacter.Name))
            CagingManager.cagePlayer(targetEntity, killerPlayer)
        end
    end
end

-- Cleanup when a player leaves
Players.PlayerRemoving:Connect(function(player)
    if lastAttackTimes[player] then
        lastAttackTimes[player] = nil
    end
end)

-- Connect the handler to the remote event
AttackRequest.OnServerEvent:Connect(onAttackRequest)

print("KillerInteractionManager (Remote Event version) is running.")
