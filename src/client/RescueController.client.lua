--[[
    RescueController.client.lua

    Handles the client-side logic for a healthy survivor to rescue a
    caged teammate from a Killer Hanger.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Modules
local CONFIG = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("Config"))

-- Player Globals
local player = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerRescueRequest_SERVER = Remotes:WaitForChild("PlayerRescueRequest_SERVER")

-- State
local targetHanger = nil
local targetSurvivor = nil

-- Helper function to check if the local player is healthy
local function isPlayerHealthy()
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then
        return false
    end
    -- A player is "healthy" if they are not in the Downed state.
    return player.Character:GetAttribute("Downed") ~= true
end

-- Proximity checks for UI prompts
RunService.RenderStepped:Connect(function()
    -- Guard Clause: Do nothing until the UI Manager is initialized.
    if not _G.UI then
        return
    end

    -- If the player isn't in a state to rescue, hide the prompt and clear targets.
    if not isPlayerHealthy() or not player.Character or not player.Character.PrimaryPart then
        _G.UI.setInteractionPrompt("")
        targetHanger = nil
        targetSurvivor = nil
        return
    end

    local myPos = player.Character.PrimaryPart.Position
    local closestHanger = nil
    local minDistance = CONFIG.HANGER_INTERACT_DISTANCE

    local hangersFolder = Workspace:FindFirstChild("Hangers")
    if hangersFolder then
        for _, hanger in ipairs(hangersFolder:GetChildren()) do
            -- A hanger is a valid target if it has a survivor attached to it.
            local hangWeld = hanger:FindFirstChild("HangWeld")
            if hangWeld and hangWeld:IsA("WeldConstraint") and hangWeld.Part1 and hangWeld.Part1.Parent and hangWeld.Part1.Parent:FindFirstChild("Humanoid") then
                local distance = (myPos - hanger.PrimaryPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestHanger = hanger
                    -- The Part1 of the weld is the HumanoidRootPart of the survivor
                    targetSurvivor = hangWeld.Part1.Parent
                end
            end
        end
    end

    if closestHanger and targetSurvivor then
        _G.UI.setInteractionPrompt("[E] to Rescue")
        targetHanger = closestHanger
    else
        _G.UI.setInteractionPrompt("")
        targetHanger = nil
        targetSurvivor = nil
    end
end)

-- Handle player input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == CONFIG.HANG_KEY then
        if targetHanger and targetSurvivor then
            -- Find the player object associated with the character model
            local survivorPlayer = Players:GetPlayerFromCharacter(targetSurvivor)
            if survivorPlayer then
                print(string.format("[RescueController] E pressed. Requesting rescue for %s.", survivorPlayer.Name))
                PlayerRescueRequest_SERVER:FireServer(survivorPlayer)
            else
                 -- It might be a bot, which doesn't have a player object. Send the model.
                print(string.format("[RescueController] E pressed. Requesting rescue for bot %s.", targetSurvivor.Name))
                PlayerRescueRequest_SERVER:FireServer(targetSurvivor)
            end
        end
    end
end)

print("RescueController.client.lua loaded and listening.")
