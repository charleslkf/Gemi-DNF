--[[
    DownedStateController.client.lua

    This client-side script listens for the "DownedStateChanged" event from the server
    and handles the visual aspects of a player entering the downed state,
    primarily by playing the crawl animation.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Player Globals
local player = Players.LocalPlayer

-- Remotes and Assets
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DownedStateChanged = Remotes:WaitForChild("DownedStateChanged")

-- Main Event Handler
DownedStateChanged.OnClientEvent:Connect(function(downedCharacter)
    -- Log #1: Confirm Event Received
    print("[AnimDiag] DownedStateChanged event received for character:", downedCharacter and downedCharacter.Name or "nil")

    if not downedCharacter then return end

    local humanoid = downedCharacter:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

    -- Log #2: Confirm Humanoid/Animator Found
    if humanoid and animator then
        print("[AnimDiag] Found Humanoid and Animator for", downedCharacter.Name)
    else
        print("[AnimDiag-ERROR] Could NOT find Humanoid or Animator for", downedCharacter.Name)
        return -- Stop if essential components are missing
    end

    -- Use WaitForChild for the animation asset to be safe
    local crawlAnimation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Crawl")

    -- Log #3: Confirm Animation Asset Found
    if crawlAnimation then
        print("[AnimDiag] Found Animation asset:", crawlAnimation.Name, "with ID:", crawlAnimation.AnimationId)
    else
        print("[AnimDiag-ERROR] Could NOT find 'Crawl' in ReplicatedStorage/Animations.")
        return -- Stop if asset is missing
    end

    -- Load and play the crawl animation locally
    local crawlTrack = animator:LoadAnimation(crawlAnimation)

    -- Log #4: Confirm Animation Loaded
    if crawlTrack then
        print("[AnimDiag] Successfully loaded animation onto Animator. Track Length:", crawlTrack.Length)
    else
        print("[AnimDiag-ERROR] Failed to load animation onto Animator!")
        return -- Stop if loading failed
    end

    crawlTrack.Priority = Enum.AnimationPriority.Action
    crawlTrack.Looped = true
    crawlTrack:Play()

    -- Log #5: Confirm Play Attempt
    print("[AnimDiag] Called Play() on crawlTrack. IsPlaying:", crawlTrack.IsPlaying, "Looped:", crawlTrack.Looped, "Priority:", crawlTrack.Priority)

    -- Also force the humanoid state on the client for good measure
    -- This can make the animation smoother and more reliable.
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    -- Log #6: Confirm Humanoid State Change
    print("[AnimDiag] Changed Humanoid state to Physics. Current State:", humanoid:GetState())
end)

print("DownedStateController.client.lua loaded and listening for diagnostics.")