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
local CONFIG = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("Config"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")
local DownedStateChanged = Remotes:WaitForChild("DownedStateChanged")
local RequestGrab = Remotes:WaitForChild("RequestGrab")
local RequestDrop = Remotes:WaitForChild("RequestDrop")
local CarryingStateChanged = Remotes:WaitForChild("CarryingStateChanged")
local RequestHang = Remotes:WaitForChild("RequestHang")
local PlayerRescueRequest_SERVER = Remotes:WaitForChild("PlayerRescueRequest_SERVER")
local PlayerRescued_CLIENT = Remotes:WaitForChild("PlayerRescued_CLIENT")

-- Bindables for server-to-server
-- Bindables for server-to-server (Idempotent Initialization)
local Bindables = ServerScriptService:FindFirstChild("Bindables")
if not Bindables then
    Bindables = Instance.new("Folder")
    Bindables.Name = "Bindables"
    Bindables.Parent = ServerScriptService
end
local PlayerRescuedInternal = Bindables:FindFirstChild("PlayerRescuedInternal")
if not PlayerRescuedInternal then
    PlayerRescuedInternal = Instance.new("BindableEvent")
    PlayerRescuedInternal.Name = "PlayerRescuedInternal"
    PlayerRescuedInternal.Parent = Bindables
end
local HealthChangedInternal_SERVER = Bindables:WaitForChild("HealthChangedInternal_SERVER")

-- Constants
local ATTACK_COOLDOWN = 5 -- seconds
local ATTACK_DAMAGE = 25
local CAGE_HEALTH_THRESHOLD = 50
local MAX_ATTACK_DISTANCE = 12 -- A little more than the client's 10 for latency tolerance

-- State
local lastAttackTimes = {} -- { [Player]: tick() }
local carrying = {} -- { [killerPlayer]: survivorCharacter }
local killersTeam = Teams:WaitForChild("Killers")
local survivorsTeam = Teams:WaitForChild("Survivors")

-- Helper function to make a character massless to prevent physics glitches
local function setMass(character, massless, partToExclude)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part ~= partToExclude then
            part.Massless = massless
        end
    end
end

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

        -- Check if the survivor/bot should be downed (only for normal attacks)
        local targetHealth = HealthManager.getHealth(targetEntity)
        if targetHealth and targetHealth <= CAGE_HEALTH_THRESHOLD then
            print(string.format("[InteractionManager] Health is %d. Putting %s into Downed state.", targetHealth, targetCharacter.Name))

            -- Set the "Downed" attribute on the character model
            targetCharacter:SetAttribute("Downed", true)

            -- Reduce the survivor's movement speed
            if targetCharacter.Humanoid then
                targetCharacter.Humanoid.WalkSpeed = 5
            end

            -- Notify all clients that the player's state has changed
            DownedStateChanged:FireAllClients(targetCharacter)
        end
    end
end

-- Cleanup when a player leaves
Players.PlayerRemoving:Connect(function(player)
    if lastAttackTimes[player] then
        lastAttackTimes[player] = nil
    end
    if carrying[player] then
        carrying[player] = nil
    end
end)

-- Connect the handler to the remote event
AttackRequest.OnServerEvent:Connect(onAttackRequest)

-- Handler for Grab Requests
local function onGrabRequest(killerPlayer, targetCharacter)
    -- 1. VALIDATION
    local killerCharacter = killerPlayer.Character
    if not killerCharacter or not killerCharacter.PrimaryPart or carrying[killerPlayer] then
        return -- Killer doesn't exist or is already carrying someone
    end

    if not targetCharacter or not targetCharacter.PrimaryPart or not targetCharacter:FindFirstChild("Humanoid") then
        return -- Target is invalid
    end

    if targetCharacter:GetAttribute("Downed") ~= true then
        return -- Target is not in the downed state
    end

    -- Server-side distance check to prevent exploits
    local distance = (killerCharacter.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    if distance > CONFIG.GRAB_DISTANCE + 2 then -- Add a small buffer for latency
        print(string.format("[InteractionManager] Grab failed: %s is too far from %s.", killerPlayer.Name, targetCharacter.Name))
        return
    end

    -- 2. APPLY GRAB LOGIC
    print(string.format("[InteractionManager] Grab validated: %s is grabbing %s.", killerPlayer.Name, targetCharacter.Name))

    -- Fully incapacitate the survivor and disable their physics to prevent dragging down the killer
    targetCharacter.Humanoid.WalkSpeed = 0

    -- Disable collisions on the survivor to prevent dragging issues
    for _, part in ipairs(targetCharacter:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = false
        end
    end

    -- ROBUSTNESS FIX: More aggressively disable all motor states to prevent movement stutter.
    targetCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    targetCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    targetCharacter.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    targetCharacter.Humanoid.PlatformStand = true -- FINAL FIX: This removes all physics drag.

    -- Make the survivor's limbs massless to prevent them from dragging or interfering with the killer's movement.
    -- Crucially, the HumanoidRootPart is NOT made massless, which prevents physics glitches.
    setMass(targetCharacter, true, targetCharacter.HumanoidRootPart)

    -- Create the weld to attach the survivor to the killer
    local weld = Instance.new("WeldConstraint")
    weld.Name = "GrabWeld"
    weld.Part0 = killerCharacter.HumanoidRootPart
    weld.Part1 = targetCharacter.HumanoidRootPart
    weld.Parent = killerCharacter.HumanoidRootPart

    -- Update killer state
    carrying[killerPlayer] = targetCharacter

    -- Notify the client that its state has changed
    CarryingStateChanged:FireClient(killerPlayer, true)
end

RequestGrab.OnServerEvent:Connect(onGrabRequest)

-- Handler for Drop Requests
local function onDropRequest(killerPlayer)
    -- 1. VALIDATION
    local killerCharacter = killerPlayer.Character
    if not killerCharacter or not killerCharacter.PrimaryPart then return end

    local carriedCharacter = carrying[killerPlayer]
    if not carriedCharacter or not carriedCharacter.Parent or not carriedCharacter:FindFirstChild("Humanoid") then
        return -- Killer isn't carrying a valid character
    end

    -- 2. APPLY DROP LOGIC
    print(string.format("[InteractionManager] Drop validated: %s is dropping %s.", killerPlayer.Name, carriedCharacter.Name))

    -- Destroy the weld
    local weld = killerCharacter.HumanoidRootPart:FindFirstChild("GrabWeld")
    if weld then
        weld:Destroy()
    end

    -- Update killer state
    carrying[killerPlayer] = nil

    -- Notify the client that its state has changed
    CarryingStateChanged:FireClient(killerPlayer, false)

    -- Restore survivor's collisions and mass
    setMass(carriedCharacter, false) -- No part excluded, so all parts are restored
    for _, part in ipairs(carriedCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end

    -- Return survivor to the "Downed" state (low speed) and re-enable their physics
    carriedCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    carriedCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    carriedCharacter.Humanoid.PlatformStand = false -- Restore normal physics
    carriedCharacter.Humanoid.WalkSpeed = 5
    carriedCharacter.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

RequestDrop.OnServerEvent:Connect(onDropRequest)

-- Handler for Hang Requests
local function onHangRequest(killerPlayer, hanger)
    -- 1. VALIDATION
    local killerCharacter = killerPlayer.Character
    if not killerCharacter or not killerCharacter.PrimaryPart then return end

    local survivorCharacter = carrying[killerPlayer]
    if not survivorCharacter or not survivorCharacter.Parent then
        return -- Killer isn't carrying a valid character
    end

    if not hanger or not hanger:IsA("Model") or not hanger:FindFirstChild("AttachPoint") then
        return -- Invalid hanger model
    end

    -- Server-side distance check
    local distance = (killerCharacter.PrimaryPart.Position - hanger.AttachPoint.Position).Magnitude
    if distance > CONFIG.HANGER_INTERACT_DISTANCE + 2 then
        return -- Too far
    end

    -- 2. APPLY HANG LOGIC
    print(string.format("[InteractionManager] Hang validated: %s is hanging %s on %s.", killerPlayer.Name, survivorCharacter.Name, hanger.Name))

    -- Detach from killer
    local weld = killerCharacter.HumanoidRootPart:FindFirstChild("GrabWeld")
    if weld then weld:Destroy() end

    carrying[killerPlayer] = nil
    CarryingStateChanged:FireClient(killerPlayer, false)

    -- Restore the survivor's mass before hanging them
    setMass(survivorCharacter, false) -- No part excluded, so all parts are restored

    -- Attach to hanger
    local hangWeld = Instance.new("WeldConstraint")
    hangWeld.Name = "HangWeld"
    hangWeld.Part0 = hanger.AttachPoint
    hangWeld.Part1 = survivorCharacter.HumanoidRootPart
    hangWeld.Parent = hanger.AttachPoint

    -- Survivor is fully incapacitated on the hanger
    survivorCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) -- Re-enable sitting
    survivorCharacter.Humanoid.PlatformStand = false -- Restore normal physics
    survivorCharacter.Humanoid.WalkSpeed = 0
    survivorCharacter.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

    -- Trigger the caging timer
    local survivorPlayer = Players:GetPlayerFromCharacter(survivorCharacter)
    if survivorPlayer then
        CagingManager.cagePlayer(survivorPlayer, killerPlayer)
    else
        -- Handle case for bots, which are just models
        CagingManager.cagePlayer(survivorCharacter, killerPlayer)
    end
end

RequestHang.OnServerEvent:Connect(onHangRequest)

-- Handler for Rescue Requests
local function onPlayerRescueRequest(rescuerPlayer, hangedSurvivorEntity)
    -- 1. VALIDATION
    local rescuerCharacter = rescuerPlayer.Character
    if not rescuerCharacter or not rescuerCharacter.PrimaryPart or rescuerCharacter:GetAttribute("Downed") == true then
        return -- Rescuer is not in a valid state to rescue
    end

    -- The entity can be a Player object or a bot's Model
    local hangedSurvivorCharacter
    if hangedSurvivorEntity:IsA("Player") then
        hangedSurvivorCharacter = hangedSurvivorEntity.Character
    else
        hangedSurvivorCharacter = hangedSurvivorEntity
    end

    if not hangedSurvivorCharacter or not hangedSurvivorCharacter.PrimaryPart then return end

    -- Find the weld to verify the survivor is actually on a hanger.
    -- This logic mirrors the robust search in onPlayerRescuedInternal.
    local hangWeld = hangedSurvivorCharacter.HumanoidRootPart:FindFirstChild("HangWeld", true) -- Recursive search
    if not hangWeld then
         -- It's possible the weld is on the hanger's AttachPoint instead, depending on timing.
         local hangersFolder = game:GetService("Workspace"):FindFirstChild("Hangers")
         if hangersFolder then
             for _, hanger in ipairs(hangersFolder:GetChildren()) do
                 local attachPoint = hanger:FindFirstChild("AttachPoint")
                 if attachPoint then
                     local foundWeld = attachPoint:FindFirstChild("HangWeld")
                     if foundWeld and foundWeld.Part1 == hangedSurvivorCharacter.HumanoidRootPart then
                         hangWeld = foundWeld
                         break
                     end
                 end
             end
         end
    end

    if not hangWeld then
        print(string.format("[InteractionManager] Rescue failed: %s is not on a hanger.", hangedSurvivorCharacter.Name))
        return
    end

    -- Server-side distance check
    local distance = (rescuerCharacter.PrimaryPart.Position - hangedSurvivorCharacter.PrimaryPart.Position).Magnitude
    if distance > CONFIG.HANGER_INTERACT_DISTANCE + 2 then
        print(string.format("[InteractionManager] Rescue failed: %s is too far from %s.", rescuerPlayer.Name, hangedSurvivorCharacter.Name))
        return
    end

    -- 2. APPLY RESCUE LOGIC
    print(string.format("[InteractionManager] Rescue validated: %s is rescuing %s.", rescuerPlayer.Name, hangedSurvivorCharacter.Name))

    -- Stop the caging timer
    CagingManager.rescuePlayer(hangedSurvivorEntity)

    -- Restore health to 51
    hangedSurvivorCharacter.Humanoid.Health = 51
    hangedSurvivorCharacter:SetAttribute("Downed", false) -- No longer downed

    -- Destroy the weld
    hangWeld:Destroy()

    -- Restore survivor's collisions and speed
    for _, part in ipairs(hangedSurvivorCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    hangedSurvivorCharacter.Humanoid.WalkSpeed = 16 -- Default speed

    -- Notify all clients of the successful rescue
    PlayerRescued_CLIENT:FireAllClients(hangedSurvivorCharacter)
end

PlayerRescueRequest_SERVER.OnServerEvent:Connect(onPlayerRescueRequest)

-- When a player is rescued by any means, check if a killer was carrying them.
-- This function now handles all server-side logic for when a player is rescued,
-- regardless of the source (teammate, self-rescue via item, etc.).
local function onPlayerRescuedInternal(rescuedEntity)
    local rescuedCharacter
    if rescuedEntity:IsA("Player") then
        rescuedCharacter = rescuedEntity.Character
    else
        rescuedCharacter = rescuedEntity -- It's a bot model
    end

    if not rescuedCharacter or not rescuedCharacter:FindFirstChild("Humanoid") then return end

    -- CASE 1: Survivor was being carried by a killer. Force a drop.
    for killerPlayer, carriedCharacter in pairs(carrying) do
        if carriedCharacter == rescuedCharacter then
            print(string.format("[InteractionManager-Internal] %s was rescued while being carried by %s. Forcing drop.", rescuedCharacter.Name, killerPlayer.Name))
            onDropRequest(killerPlayer)
            -- Don't break here; a player could theoretically be on a hook *and* carried (if a bug occurs).
        end
    end

    -- CASE 2: Survivor was on a hanger. Release them.
    -- Find the HangWeld by searching from the HumanoidRootPart upwards.
    local hangWeld = rescuedCharacter.HumanoidRootPart:FindFirstChild("HangWeld", true) -- Recursive search
    if not hangWeld then
         -- It's possible the weld is on the hanger's AttachPoint instead, depending on timing.
         local hangersFolder = Workspace:FindFirstChild("Hangers")
         if hangersFolder then
             for _, hanger in ipairs(hangersFolder:GetChildren()) do
                 local attachPoint = hanger:FindFirstChild("AttachPoint")
                 if attachPoint then
                     local foundWeld = attachPoint:FindFirstChild("HangWeld")
                     if foundWeld and foundWeld.Part1 == rescuedCharacter.HumanoidRootPart then
                         hangWeld = foundWeld
                         break
                     end
                 end
             end
         end
    end

    if hangWeld then
        print(string.format("[InteractionManager-Internal] %s was rescued from a hanger. Releasing.", rescuedCharacter.Name))
        hangWeld:Destroy()

        -- Restore health and state
        rescuedCharacter.Humanoid.Health = 51
        rescuedCharacter:SetAttribute("Downed", false)

        -- Restore collisions, motor abilities, mass, and speed
        setMass(rescuedCharacter, false) -- No part excluded, so all parts are restored
        for _, part in ipairs(rescuedCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        rescuedCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        rescuedCharacter.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        rescuedCharacter.Humanoid.PlatformStand = false -- Restore normal physics
        rescuedCharacter.Humanoid.WalkSpeed = 16 -- Default speed

        -- Notify clients of the state change
        PlayerRescued_CLIENT:FireAllClients(rescuedCharacter)
    end
end

PlayerRescuedInternal.Event:Connect(onPlayerRescuedInternal)

-- When a player's health changes, check if they should be taken out of the downed state.
local function onHealthChanged(entity, currentHealth, maxHealth)
    -- The entity can be a Player object or a bot's Model
    local character
    if entity:IsA("Player") then
        character = entity.Character
    else
        character = entity
    end

    if not character or not character:FindFirstChild("Humanoid") then return end

    -- Check if the character is currently downed
    if character:GetAttribute("Downed") == true then
        -- If health is now above the threshold, stand them up
        if currentHealth > CAGE_HEALTH_THRESHOLD then
            print(string.format("[InteractionManager] %s's health is above threshold. Removing Downed state.", character.Name))
            character:SetAttribute("Downed", nil) -- Remove the attribute
            character.Humanoid.WalkSpeed = 16 -- Restore default walk speed

            -- Notify clients that the state has changed
            DownedStateChanged:FireAllClients(character)
        end
    end
end

HealthChangedInternal_SERVER.Event:Connect(onHealthChanged)


print("KillerInteractionManager (Remote Event version) is running.")
