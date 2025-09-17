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
local function onAttackRequest(killerPlayer, targetPlayer)
    -- Lazily require all modules on first execution
    if not HealthManager then
        HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
        CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
        KillerAbilityManager = require(ServerScriptService:WaitForChild("KillerAbilityManager"))
    end

    -- 1. VALIDATION AND SECURITY CHECKS

    -- Verify the players exist and have characters
    if not killerPlayer or not targetPlayer or not killerPlayer.Character or not targetPlayer.Character then
        return
    end

    -- Verify team affiliations
    if killerPlayer.Team ~= killersTeam or targetPlayer.Team ~= survivorsTeam then
        return
    end

    -- Verify the killer is not on cooldown
    local lastAttack = lastAttackTimes[killerPlayer]
    if lastAttack and (tick() - lastAttack < ATTACK_COOLDOWN) then
        print(string.format("[InteractionManager] Attack blocked: %s is on cooldown.", killerPlayer.Name))
        return
    end

    -- Verify distance again on the server to prevent exploits
    local distance = (killerPlayer.Character.PrimaryPart.Position - targetPlayer.Character.PrimaryPart.Position).Magnitude
    if distance > MAX_ATTACK_DISTANCE then
        print(string.format("[InteractionManager] Attack blocked: %s is too far from %s (%.1f studs).", killerPlayer.Name, targetPlayer.Name, distance))
        return
    end

    -- Verify the target is not already caged
    if CagingManager.isCaged(targetPlayer) then
        print(string.format("[InteractionManager] Attack blocked: %s is already caged.", targetPlayer.Name))
        return
    end

    -- 2. APPLY GAME LOGIC

    print(string.format("[InteractionManager] Attack validated: %s hit %s.", killerPlayer.Name, targetPlayer.Name))

    -- Set the cooldown *before* applying damage
    lastAttackTimes[killerPlayer] = tick()

    -- Check if the killer's ultimate is active
    if KillerAbilityManager.isUltimateActive(killerPlayer) then
        -- Perform an instant elimination
        KillerAbilityManager.performUltimateKill(targetPlayer, killerPlayer)
    else
        -- Apply normal damage, passing the killerPlayer as the damageDealer
        HealthManager.applyDamage(targetPlayer, ATTACK_DAMAGE, killerPlayer)

        -- Check if the survivor should be caged (only for normal attacks)
        local survivorHealth = HealthManager.getHealth(targetPlayer)
        if survivorHealth and survivorHealth <= CAGE_HEALTH_THRESHOLD then
            print(string.format("[InteractionManager] Health is %d, attempting to cage %s.", survivorHealth, targetPlayer.Name))
            CagingManager.cagePlayer(targetPlayer, killerPlayer)
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
