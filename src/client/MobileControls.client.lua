--[[
    MobileControls.client.lua
    by Jules

    This script provides a touch-based "Interact" button for Survivors on mobile devices.
    It handles contextual actions like repairing machines and rescuing teammates.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Only run this script on touch-enabled (mobile) devices
if not UserInputService.TouchEnabled then
    print("MobileControls: Not a touch device, script will not run.")
    return
end

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules & Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerRescueRequest_SERVER = Remotes:WaitForChild("PlayerRescueRequest_SERVER")
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local CagingManager = require(MyModules:WaitForChild("CagingManager"))
local MiniGameManager = require(MyModules:WaitForChild("MiniGameManager"))
local CONFIG = require(MyModules:WaitForChild("Config"))

-- Create UI
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name = "MobileControlsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- Ensure it respects ZIndex globally

local interactButton = Instance.new("TextButton", screenGui)
interactButton.Name = "InteractButton"
interactButton.Text = "INTERACT"
interactButton.Font = Enum.Font.SourceSansBold
interactButton.TextSize = 20
interactButton.TextColor3 = Color3.new(1, 1, 1)
interactButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255) -- A solid, visible blue
interactButton.Size = UDim2.new(0, 150, 0, 80) -- Making it a rectangle
interactButton.AnchorPoint = Vector2.new(0, 0.5) -- Middle-left
interactButton.Position = UDim2.new(0, 30, 0.5, 0)
interactButton.Visible = false
interactButton.ZIndex = 10 -- Set a high ZIndex to ensure it's on top

-- State to track the current interaction target
local currentInteractionTarget = nil

-- Proximity checking loop
RunService.RenderStepped:Connect(function()
    if not CONFIG or not CONFIG.MACHINE_FOLDER_NAME then
        -- The config module hasn't loaded yet, so do nothing.
        return
    end

    local character = player.Character
    if not character or not character.PrimaryPart then
        interactButton.Visible = false
        currentInteractionTarget = nil
        return
    end

    -- Only run for survivors who are not downed
    if player.Team and player.Team.Name == "Survivors" and character:GetAttribute("Downed") ~= true then
        local playerPos = character.PrimaryPart.Position
        local foundTarget = nil

        -- Priority 1: Check for caged teammates
        local hangers = Workspace:FindFirstChild("Hangers")
        if hangers then
            for _, hanger in ipairs(hangers:GetChildren()) do
                local attachPoint = hanger:FindFirstChild("AttachPoint")
                if attachPoint then
                    local hangWeld = attachPoint:FindFirstChild("HangWeld")
                    if hangWeld and hangWeld.Part1 then
                        local survivorPart = hangWeld.Part1
                        local distance = (playerPos - survivorPart.Position).Magnitude
                        if distance <= CONFIG.HANGER_INTERACT_DISTANCE then
                            local survivorChar = survivorPart.Parent
                            local survivorPlayer = Players:GetPlayerFromCharacter(survivorChar)
                            if survivorPlayer and CagingManager.isCaged(survivorPlayer) then
                                foundTarget = survivorPlayer -- Target is the Player object
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Priority 2: Check for machines (only if no rescue target was found)
        if not foundTarget then
            local machinesFolder = Workspace:FindFirstChild(CONFIG.MACHINE_FOLDER_NAME)
            if machinesFolder then
                 for _, machine in ipairs(machinesFolder:GetChildren()) do
                    if machine:IsA("Model") and machine.PrimaryPart then
                        local distance = (playerPos - machine.PrimaryPart.Position).Magnitude
                        if distance <= CONFIG.INTERACTION_DISTANCE and not machine:GetAttribute("IsCompleted") then
                            foundTarget = machine -- Target is the Machine model
                            break -- Found a target, no need to check further
                        end
                    end
                end
            end
        end

        -- Update visibility and target
        if foundTarget then
            interactButton.Visible = true
            currentInteractionTarget = foundTarget
        else
            interactButton.Visible = false
            currentInteractionTarget = nil
        end

    else
        -- Hide for killers or downed survivors
        interactButton.Visible = false
        currentInteractionTarget = nil
    end
end)

-- Handle the button tap
interactButton.Activated:Connect(function()
    if not currentInteractionTarget then return end

    -- Check if the target is a Player (meaning a caged teammate)
    if currentInteractionTarget:IsA("Player") then
        print("[MobileControls] Interacting with caged player:", currentInteractionTarget.Name)
        PlayerRescueRequest_SERVER:FireServer(currentInteractionTarget)

    -- Check if the target is a Model (meaning a machine)
    elseif currentInteractionTarget:IsA("Model") then
        print("[MobileControls] Interacting with machine:", currentInteractionTarget.Name)
        -- Use the newly exposed function from MiniGameManager
        MiniGameManager.triggerMiniGame(currentInteractionTarget)
    end
end)

print("MobileControls.client.lua loaded and running on a touch device.")
