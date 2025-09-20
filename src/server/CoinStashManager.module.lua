--[[
    CoinStashManager.module.lua
    by Jules

    This server-side module handles the procedural creation, spawning,
    and management of Coin Stashes within the game world.
]]

local Workspace = game:GetService("Workspace")

local CoinStashManager = {}

-- Configuration
local CONFIG = {
    NumberOfStashes = 5,
    StashFolderName = "CoinStashes",
    SpawnArea = {
        Min = Vector3.new(-50, 2, -50),
        Max = Vector3.new(50, 2, 50)
    }
}

-- Variable to hold the folder reference
local stashContainer = nil

-- Private helper function to create the chest model
local function _createChestModel()
    local chestModel = Instance.new("Model")
    chestModel.Name = "CoinStash"

    -- Create the base of the chest
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(3, 2, 2)
    base.Color = Color3.fromRGB(139, 69, 19) -- Brown color
    base.Material = Enum.Material.Wood
    base.Anchored = true
    base.Parent = chestModel

    -- Create the lid of the chest
    local lid = Instance.new("Part")
    lid.Name = "Lid"
    lid.Size = Vector3.new(3, 0.5, 2)
    lid.Color = Color3.fromRGB(255, 215, 0) -- Gold color
    lid.Material = Enum.Material.Metal
    lid.Position = base.Position + Vector3.new(0, 1.25, 0)
    lid.Anchored = true
    lid.Parent = chestModel

    -- Set the primary part for easy CFrame manipulation
    chestModel.PrimaryPart = base

    -- Weld the lid to the base
    local lidWeld = Instance.new("WeldConstraint")
    lidWeld.Part0 = base
    lidWeld.Part1 = lid
    lidWeld.Parent = base

    return chestModel
end

function CoinStashManager.spawnStashes()
    if stashContainer then
        warn("CoinStashManager: Stashes already exist.")
        return
    end

    print("CoinStashManager: Spawning stashes.")
    stashContainer = Instance.new("Folder")
    stashContainer.Name = CONFIG.StashFolderName
    stashContainer.Parent = Workspace

    for i = 1, CONFIG.NumberOfStashes do
        local chest = _createChestModel()
        local x = math.random(CONFIG.SpawnArea.Min.X, CONFIG.SpawnArea.Max.X)
        local z = math.random(CONFIG.SpawnArea.Min.Z, CONFIG.SpawnArea.Max.Z)
        local y = CONFIG.SpawnArea.Min.Y -- Keep Y fixed for simplicity
        chest:SetPrimaryPartCFrame(CFrame.new(x, y, z))
        chest.Parent = stashContainer
    end
end

function CoinStashManager.cleanupStashes()
    if stashContainer then
        print("CoinStashManager: Cleaning up stashes.")
        stashContainer:Destroy()
        stashContainer = nil
    end
end

function CoinStashManager.initialize()
    print("CoinStashManager initialized.")
end

return CoinStashManager
