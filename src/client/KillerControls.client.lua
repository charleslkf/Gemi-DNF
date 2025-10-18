--[[
    KillerControls.client.lua

    This client-side script handles the killer's ability to attack survivors.
    It's responsible for detecting clicks on survivors, checking proximity,
    and notifying the server of a valid attack attempt.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Player Globals
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Configuration
local MAX_ATTACK_DISTANCE = 10

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")
local RequestGrab = Remotes:WaitForChild("RequestGrab")

-- Configuration
local MAX_GRAB_DISTANCE = 15

-- State
local killersTeam = Teams:WaitForChild("Killers")

-- Function to check if the player is a killer
local function isKiller()
    return player.Team == killersTeam
end

-- Helper function to find a character model from any of its descendant parts
local function findCharacterFromPart(part)
    if not part then return nil end
    local current = part
    -- A model can be nested, so we search up to 5 levels deep.
    for _ = 1, 5 do
        if current and current:FindFirstChildWhichIsA("Humanoid") then
            return current
        end
        if not current or not current.Parent then
            return nil
        end
        current = current.Parent
    end
    return nil
end

-- Main Attack Logic
local function onAttackInput(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed then
        return
    end

    if not isKiller() or not player.Character or not player.Character.PrimaryPart then
        return
    end

    local targetPart = mouse.Target
    if not targetPart then return end

    local targetCharacter = findCharacterFromPart(targetPart)
    if not targetCharacter or targetCharacter == player.Character then
        return
    end

    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if targetPlayer and targetPlayer.Team == killersTeam then
        return
    elseif not targetPlayer and not targetCharacter.Name:match("^Bot") then
        return
    end

    local distance = (player.Character.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    if distance > MAX_ATTACK_DISTANCE then
        return
    end

    print(string.format("Attack success: Firing remote for %s.", targetCharacter.Name))
    AttackRequest:FireServer(targetCharacter)
end

-- Grab Logic
local function onGrabInput(input, gameProcessed)
    if input.KeyCode ~= Enum.KeyCode.F or gameProcessed then
        return
    end

    if not isKiller() or not player.Character or not player.Character.PrimaryPart then
        return
    end

    -- Find the nearest downed character
    local killerPos = player.Character.PrimaryPart.Position
    local nearestDownedChar, minDistance = nil, MAX_GRAB_DISTANCE

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:GetAttribute("Downed") then
            local distance = (killerPos - otherPlayer.Character.PrimaryPart.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                nearestDownedChar = otherPlayer.Character
            end
        end
    end

    -- Also check for downed bots
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:match("^Bot") and model:GetAttribute("Downed") then
            if model.PrimaryPart then
                local distance = (killerPos - model.PrimaryPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestDownedChar = model
                end
            end
        end
    end

    if nearestDownedChar then
        print(string.format("Requesting to grab downed character: %s", nearestDownedChar.Name))
        RequestGrab:FireServer(nearestDownedChar)
    end
end

-- Connect the handlers to user input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    onAttackInput(input, gameProcessed)
    onGrabInput(input, gameProcessed)
end)

print("KillerControls.client.lua loaded.")
