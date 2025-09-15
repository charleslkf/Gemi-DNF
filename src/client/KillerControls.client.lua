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

-- Configuration
local MAX_ATTACK_DISTANCE = 10

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")

-- State
local killersTeam = Teams:WaitForChild("Killers")

-- Function to check if the player is a killer
local function isKiller()
    return player.Team == killersTeam
end

-- Main Attack Logic
local function onInputBegan(input, gameProcessed)
    -- Only proceed if input was a left-click and not handled by the game engine already
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed then
        return
    end

    -- Abort if the player is not a killer or if their character doesn't exist
    if not isKiller() or not player.Character or not player.Character.PrimaryPart then
        return
    end

    local target = input.Target
    if not target or not target.Parent then
        return
    end

    -- Find the player associated with the clicked part
    local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)

    -- Abort if the target isn't a player or is the killer themself
    if not targetPlayer or targetPlayer == player then
        return
    end

    -- Abort if the target player is not a survivor
    if targetPlayer.Team == killersTeam then
        return
    end

    -- Abort if the target's character doesn't exist
    local targetCharacter = targetPlayer.Character
    if not targetCharacter or not targetCharacter.PrimaryPart then
        return
    end

    -- Check the distance between the killer and the survivor
    local distance = (player.Character.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    if distance > MAX_ATTACK_DISTANCE then
        print(string.format("Attack failed: %s is too far away (%.1f studs).", targetPlayer.Name, distance))
        return
    end

    -- If all checks pass, notify the server
    print(string.format("Attack success: Firing remote for %s.", targetPlayer.Name))
    AttackRequest:FireServer(targetPlayer)
end

-- Connect the handler to user input
UserInputService.InputBegan:Connect(onInputBegan)

print("KillerControls.client.lua loaded.")
