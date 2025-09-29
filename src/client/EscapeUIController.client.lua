-- EscapeUIController.client.lua
-- THIS IS A TEMPORARY DIAGNOSTIC SCRIPT

print("[DIAGNOSTIC] EscapeUIController script has started.")

-- Define services and local player
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[DIAGNOSTIC] PlayerGui found:", playerGui.Name)

-- 1. VERIFY THE REMOTE EVENT
local remoteEvent = ReplicatedStorage:FindFirstChild("EscapeSequenceStarted")
if not remoteEvent then
    print("[DIAGNOSTIC-FATAL] COULD NOT FIND 'EscapeSequenceStarted' RemoteEvent in ReplicatedStorage.")
    return -- Stop the script
end
print("[DIAGNOSTIC] Successfully found RemoteEvent:", remoteEvent.Name)

-- 2. VERIFY THE UI HIERARCHY
local mainHUD = playerGui:WaitForChild("MainHUD", 5) -- Wait up to 5 seconds
if not mainHUD then
    print("[DIAGNOSTIC-FATAL] COULD NOT FIND 'MainHUD' ScreenGui in PlayerGui.")
    return -- Stop the script
end
print("[DIAGNOSTIC] Successfully found ScreenGui:", mainHUD.Name)

local escapeArrow = mainHUD:FindFirstChild("EscapeArrow")
if not escapeArrow then
    print("[DIAGNOSTIC-FATAL] COULD NOT FIND 'EscapeArrow' ImageLabel inside MainHUD.")
    return -- Stop the script
end
print("[DIAGNOSTIC] Successfully found ImageLabel:", escapeArrow.Name)

-- 3. CONNECT THE LISTENER
remoteEvent.OnClientEvent:Connect(function(gate1Pos, gate2Pos)
    print("[DIAGNOSTIC-SUCCESS] 'OnClientEvent' FIRED! The event was received from the server.")

    -- Log the data received from the server
    print("[DIAGNOSTIC] Data received for Gate1:", gate1Pos)
    print("[DIAGNOSTIC] Data received for Gate2:", gate2Pos)

    -- Attempt to make the arrow visible
    if mainHUD and escapeArrow then
        mainHUD.Enabled = true
        escapeArrow.Visible = true
        print("[DIAGNOSTIC] Set mainHUD.Enabled and escapeArrow.Visible to TRUE.")
    end
end)

print("[DIAGNOSTIC] Script setup complete. Now listening for 'EscapeSequenceStarted' event.")