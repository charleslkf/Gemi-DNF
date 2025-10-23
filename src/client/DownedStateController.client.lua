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

-- Function to apply or remove the downed state visuals
local function updateDownedState(character)
    if not character or not character:FindFirstChild("Humanoid") then return end

    local humanoid = character.Humanoid
    local isDowned = character:GetAttribute("Downed") == true

    if isDowned then
        -- Apply downed state
        humanoid.WalkSpeed = 5
        -- In a real game, you would play a crawling animation here
        print(string.format("[DownedStateController] %s is now in a downed state.", character.Name))
    else
        -- Remove downed state
        humanoid.WalkSpeed = 16 -- Restore default speed
        -- In a real game, you would stop the crawling animation here
        print(string.format("[DownedStateController] %s is no longer in a downed state.", character.Name))
    end
end

-- Listen for the server event that fires when any player's state changes
DownedStateChanged.OnClientEvent:Connect(function(changedCharacter)
    print("[DownedStateController] Received DownedStateChanged event.")
    updateDownedState(changedCharacter)
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
