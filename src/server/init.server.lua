-- Gemi-DNF 1: Did Not Finish Obby
-- This script will manage the game logic.

print("Gemi-DNF 1 server script loaded!")

-- Create a folder for the obby parts
local obbyFolder = Instance.new("Folder")
obbyFolder.Name = "Obby"
obbyFolder.Parent = game.Workspace

-- Function to create a single platform
local function createPlatform(position, size, color)
    local part = Instance.new("Part")
    part.Position = position
    part.Size = size
    part.Color = color
    part.Anchored = true
    part.Parent = obbyFolder
    return part
end

-- Create the platforms
local startPosition = Vector3.new(0, 10, 0)
local platformSize = Vector3.new(10, 1, 10)
local platformGap = Vector3.new(10, 0, 0)

for i = 1, 5 do
    local platformPosition = startPosition + (platformGap * (i - 1))
    if i == 4 then
        -- Make the 4th platform unreachable
        platformPosition = platformPosition + Vector3.new(20, 10, 0)
    end
    createPlatform(platformPosition, platformSize, Color3.new(0.5, 0.5, 0.5))
end

print("Obby foundation created!")

-- Create a "fall detector" part
local fallDetector = Instance.new("Part")
fallDetector.Name = "FallDetector"
fallDetector.Size = Vector3.new(500, 10, 500)
fallDetector.Position = Vector3.new(20, -20, 0) -- Positioned below the obby
fallDetector.Anchored = true
fallDetector.CanCollide = false
fallDetector.Transparency = 1
fallDetector.Parent = obbyFolder

-- Function to handle when a player touches the fall detector
local function onFell(otherPart)
    local character = otherPart.Parent
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")

    if humanoid then
        local player = game.Players:GetPlayerFromCharacter(character)
        if player then
            -- Player has fallen, show DNF message
            local playerGui = player:WaitForChild("PlayerGui")

            -- Check if the GUI is already there to avoid creating it multiple times
            if not playerGui:FindFirstChild("DNFGui") then
                -- Create the GUI
                local screenGui = Instance.new("ScreenGui")
                screenGui.Name = "DNFGui"
                screenGui.ResetOnSpawn = false

                local textLabel = Instance.new("TextLabel")
                textLabel.Text = "You Did Not Finish!"
                textLabel.Size = UDim2.new(1, 0, 0, 100)
                textLabel.Position = UDim2.new(0, 0, 0.4, 0)
                textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
                textLabel.BackgroundTransparency = 0.5
                textLabel.TextColor3 = Color3.new(1, 1, 1)
                textLabel.Font = Enum.Font.SourceSansBold
                textLabel.TextSize = 50
                textLabel.Parent = screenGui

                screenGui.Parent = playerGui

                -- Respawn the player after a delay and remove the GUI
                wait(3)
                player:LoadCharacter()
                screenGui:Destroy()
            end
        end
    end
end

fallDetector.Touched:Connect(onFell)
