--[[
    DownedStateController.client.lua

    This client-side script listens for the "DownedStateChanged" event from the server
    and handles the visual aspects of a player entering the downed state,
    primarily by playing the crawl animation.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes and Assets
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DownedStateChanged = Remotes:WaitForChild("DownedStateChanged")
local CrawlAnimation = ReplicatedStorage:WaitForChild("CrawlAnimation")

-- Main Event Handler
DownedStateChanged.OnClientEvent:Connect(function(downedCharacter)
    if not downedCharacter then return end

    local humanoid = downedCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Disable the default animation script to prevent conflicts
    local animateScript = downedCharacter:FindFirstChild("Animate")
    if animateScript and animateScript:IsA("LocalScript") then
        animateScript.Disabled = true
    end

    -- Load and play the crawl animation locally
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local crawlTrack = animator:LoadAnimation(CrawlAnimation)

    crawlTrack.Priority = Enum.AnimationPriority.Action2
    crawlTrack.Looped = true
    crawlTrack:Play()

    -- We do not need to force the humanoid state if we disable the Animate script.
    -- The priority and disabled script handle it correctly.
end)

print("DownedStateController.client.lua loaded and listening.")