--[[
    KillerControls.client.lua (DEBUG v1.5.5)

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

    print("[DEBUG] KillerControls: MouseButton1 click detected.")

    -- Abort if the player is not a killer or if their character doesn't exist
    print(string.format("[DEBUG] KillerControls: Checking player team. Player.Team is: %s", tostring(player.Team)))
    if not isKiller() then
        print("[DEBUG] KillerControls: FAIL - Player is not on Killers team.")
        return
    end
    print("[DEBUG] KillerControls: PASS - Player is on Killers team.")

    if not player.Character or not player.Character.PrimaryPart then
        print("[DEBUG] KillerControls: FAIL - Player character or PrimaryPart not found.")
        return
    end
    print("[DEBUG] KillerControls: PASS - Player character is valid.")

    local target = mouse.Target
    if not target or not target.Parent then
        print("[DEBUG] KillerControls: FAIL - Mouse target is nil or has no parent.")
        return
    end
    print(string.format("[DEBUG] KillerControls: PASS - Mouse target is %s", target.Name))

    -- Find the player associated with the clicked part
    local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)

    if not targetPlayer or targetPlayer == player then
        print("[DEBUG] KillerControls: FAIL - Target is not a player or is self.")
        return
    end
    print(string.format("[DEBUG] KillerControls: PASS - Target is a valid player: %s", targetPlayer.Name))

    -- Abort if the target player is not a survivor
    if targetPlayer.Team == killersTeam then
        print(string.format("[DEBUG] KillerControls: FAIL - Target player %s is also a killer.", targetPlayer.Name))
        return
    end
    print("[DEBUG] KillerControls: PASS - Target player is a survivor.")

    local targetCharacter = targetPlayer.Character
    if not targetCharacter or not targetCharacter.PrimaryPart then
        print("[DEBUG] KillerControls: FAIL - Target character or PrimaryPart not found.")
        return
    end
    print("[DEBUG] KillerControls: PASS - Target character is valid.")

    -- Check the distance between the killer and the survivor
    local distance = (player.Character.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    print(string.format("[DEBUG] KillerControls: Distance to target is %.1f studs.", distance))
    if distance > MAX_ATTACK_DISTANCE then
        print(string.format("[DEBUG] KillerControls: FAIL - Target is too far away."))
        return
    end
    print("[DEBUG] KillerControls: PASS - Target is within range.")

    -- If all checks pass, notify the server
    print("[DEBUG] KillerControls: SUCCESS - All checks passed. Firing AttackRequest remote.")
    AttackRequest:FireServer(targetPlayer)
end

-- Connect the handler to user input
UserInputService.InputBegan:Connect(onInputBegan)

print("KillerControls.client.lua loaded. (DEBUG v1.5.5)")
