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
local activeCrawlTracks = {} -- [Character] = AnimationTrack

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

    activeCrawlTracks[downedCharacter] = crawlTrack
end)

-- Listen for attribute changes to stop the animation when carried
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
        descendant:GetAttributeChangedSignal("BeingCarried"):Connect(function()
            if descendant:GetAttribute("BeingCarried") == true then
                if activeCrawlTracks[descendant] then
                    activeCrawlTracks[descendant]:Stop()
                    activeCrawlTracks[descendant] = nil
                end
            end
        end)
    end
end)

print("DownedStateController.client.lua loaded and listening.")