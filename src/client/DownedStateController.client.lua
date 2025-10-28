--[[
    DownedStateController.client.lua
    by Jules

    This script manages the client-side effects of the "Downed" state for a survivor.
    It listens for server events and attribute changes to apply animations and movement penalties.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DownedStateChanged = Remotes:WaitForChild("DownedStateChanged")
local PlayerRescued_CLIENT = Remotes:WaitForChild("PlayerRescued_CLIENT")
local CrawlAnimation = ReplicatedStorage:WaitForChild("CrawlAnimation")

-- State to keep track of a character's currently playing crawl animation track
local activeCrawlTracks = {} -- { [character]: AnimationTrack }

-- Function to apply or remove the downed state visuals
local function updateDownedState(character)
    if not character or not character:FindFirstChild("Humanoid") then return end

    local humanoid = character.Humanoid
    local isDowned = character:GetAttribute("Downed") == true

    -- Stop any existing animation track for this character first
    if activeCrawlTracks[character] then
        activeCrawlTracks[character]:Stop()
        activeCrawlTracks[character] = nil
    end

    if isDowned then
        -- If walkspeed is 0, the player is being carried, so no animation should play.
        if humanoid.WalkSpeed == 0 then
            print("[DownedStateController] Survivor is downed but being carried. No animation.")
            return
        end

        -- Apply downed state visuals
        humanoid.WalkSpeed = 5

        -- Disable the default animation script to prevent conflicts
        local animateScript = character:FindFirstChild("Animate")
        if animateScript then
            animateScript.Disabled = true
        end

        -- Play the crawling animation if it's not already playing
        if not activeCrawlTracks[character] then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                local crawlTrack = animator:LoadAnimation(CrawlAnimation)
                crawlTrack.Priority = Enum.AnimationPriority.Action2
                crawlTrack.Looped = true
                crawlTrack:Play()
                activeCrawlTracks[character] = crawlTrack -- Store the track
                print(string.format("[DownedStateController] Playing crawl animation for %s.", character.Name))
            end
        end
    else
        -- Remove downed state (this case is already handled by the stop logic at the top)
        humanoid.WalkSpeed = 16 -- Restore default speed
        print(string.format("[DownedStateController] %s is no longer in a downed state.", character.Name))
    end
end

-- Listen for the server event that fires when any player's state changes
DownedStateChanged.OnClientEvent:Connect(function(changedCharacter)
    print("[DownedStateController] Received DownedStateChanged event.")
    updateDownedState(changedCharacter)
end)

-- A rescue is a definitive end to the downed state, so we must listen for it.
-- This is the primary fix for the animation bug.
PlayerRescued_CLIENT.OnClientEvent:Connect(function(rescuedCharacter)
    if not rescuedCharacter then return end

    -- This cleanup logic should only run for the player who was actually rescued.
    if rescuedCharacter == player.Character then
        print("[DownedStateController] PlayerRescued_CLIENT received for LocalPlayer. Cleaning up state.")

        -- 1. Stop the crawl animation
        if activeCrawlTracks[rescuedCharacter] then
            activeCrawlTracks[rescuedCharacter]:Stop()
            activeCrawlTracks[rescuedCharacter] = nil
        end

        -- 2. Re-enable the default Animate script
        local animateScript = rescuedCharacter:FindFirstChild("Animate")
        if animateScript then
            animateScript.Disabled = false
        end

        -- 3. (Safeguard) Restore walk speed
        local humanoid = rescuedCharacter:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
        end

        -- 4. Remove the "Downed" attribute to ensure client state is consistent
        rescuedCharacter:SetAttribute("Downed", nil)
    end
end)

-- Also, monitor the local player's character for attribute changes directly.
-- This is a fallback to ensure consistency if an event is missed.
player.CharacterAdded:Connect(function(character)
    -- Initial check when the character spawns
    updateDownedState(character)

    -- Listen for any attribute changes on the character model
    character.AttributeChanged:Connect(function(attributeName)
        if attributeName == "Downed" then
            print("[DownedStateController] Detected 'Downed' attribute change.")
            updateDownedState(character)
        end
    end)
end)

print("DownedStateController.client.lua loaded and listening.")
