--[[
    KillerAbilityManager.module.lua
    by Jules

    This script manages the Killer's ultimate ability.
    - Listens for elimination events to track kills.
    - Triggers the ultimate ability when conditions are met.
    - Provides functions for other systems to query the ultimate's state.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules (forward declared for lazy loading)
local CagingManager

-- The Module
local KillerAbilityManager = {}

-- Configuration
local ELIMINATIONS_FOR_ULTIMATE = 3
local ULTIMATE_DURATION = 10 -- seconds
local ULTIMATE_SOUND_ID = "rbxassetid://2649334024" -- A placeholder menacing sound

-- State
local ultimateActive = {}    -- { [Player]: boolean }

--[[
    This function is connected to the EliminationEvent.
    It increments the killer's "Kills" leaderstat and triggers the ultimate if the threshold is met.
]]
function KillerAbilityManager.onElimination(eliminatedEntity, killer)
    if not killer or not killer:IsA("Player") then return end

    local leaderstats = killer:FindFirstChild("leaderstats")
    local killsStat = leaderstats and leaderstats:FindFirstChild("Kills")

    if not killsStat then
        warn("[AbilityManager] Killer " .. killer.Name .. " does not have a Kills leaderstat.")
        return
    end

    -- Increment the leaderstat value
    killsStat.Value = killsStat.Value + 1
    local currentKills = killsStat.Value
    print(string.format("[AbilityManager] %s now has %d eliminations.", killer.Name, currentKills))

    -- Check if the cumulative kill count is a multiple of the threshold
    if currentKills > 0 and currentKills % ELIMINATIONS_FOR_ULTIMATE == 0 then
        KillerAbilityManager.triggerUltimate(killer)
    end
end

--[[
    Activates the ultimate ability for a specific killer.
    Creates visual/audio effects and starts the countdown timer.
]]
function KillerAbilityManager.triggerUltimate(killer)
    if not killer or ultimateActive[killer] then return end

    print(string.format("[AbilityManager] Triggering ULTIMATE for %s!", killer.Name))
    ultimateActive[killer] = true

    local character = killer.Character
    if not character then
        ultimateActive[killer] = nil -- Can't apply effects, so cancel
        return
    end

    -- Create visual and audio effects
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local trail = Instance.new("Trail")
        trail.Attachment0 = rootPart:FindFirstChild("RootRigAttachment")
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        trail.Lifetime = 0.5
        trail.Transparency = NumberSequence.new(0.5)
        trail.Parent = rootPart

        local sound = Instance.new("Sound")
        sound.SoundId = ULTIMATE_SOUND_ID
        sound.Looped = true
        sound.Volume = 3
        sound.Parent = rootPart
        sound:Play()

        -- Start countdown to deactivate
        task.delay(ULTIMATE_DURATION, function()
            if not ultimateActive[killer] then return end -- In case player disconnected
            print(string.format("[AbilityManager] Ultimate for %s has ended.", killer.Name))
            ultimateActive[killer] = nil
            if trail then trail:Destroy() end
            if sound then sound:Destroy() end
        end)
    else
        -- If effects can't be applied, cancel the ultimate
        ultimateActive[killer] = nil
    end
end

--[[
    Allows other scripts to check if a killer's ultimate is currently active.
]]
function KillerAbilityManager.isUltimateActive(killer)
    return ultimateActive[killer] == true
end

--[[
    Instantly eliminates a survivor. Called by KillerInteractionManager during an ultimate.
]]
function KillerAbilityManager.performUltimateKill(survivor, killer)
    if not survivor or not killer then return end

    -- Lazily require CagingManager to avoid circular dependencies
    if not CagingManager then
        CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
    end

    print(string.format("[AbilityManager] %s used their ultimate to eliminate %s!", killer.Name, survivor.Name))
    -- The CagingManager's eliminatePlayer function handles the actual elimination
    -- and will fire the EliminationEvent, which this script listens for.
    CagingManager.eliminatePlayer(survivor, killer)
end

-- Cleanup when a player leaves
Players.PlayerRemoving:Connect(function(player)
    eliminationCounts[player] = nil
    ultimateActive[player] = nil
end)

-- Connect to the elimination event to track kills
local eliminationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EliminationEvent")
eliminationEvent.Event:Connect(KillerAbilityManager.onElimination)

return KillerAbilityManager
