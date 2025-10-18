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

local AnimationsFolder = ReplicatedStorage:WaitForChild("Animations")
local crawlAnimation = AnimationsFolder:WaitForChild("Crawl")

-- Main Event Handler
DownedStateChanged.OnClientEvent:Connect(function(downedCharacter)
    if not downedCharacter then return end

    local humanoid = downedCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Load and play the crawl animation locally
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local crawlTrack = animator:LoadAnimation(crawlAnimation)
    crawlTrack.Priority = Enum.AnimationPriority.Action
    crawlTrack:Play()
    crawlTrack.Looped = true

    -- Also force the humanoid state on the client for good measure
    -- This can make the animation smoother and more reliable.
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end)

print("DownedStateController.client.lua loaded and listening.")