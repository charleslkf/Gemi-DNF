--[[
    MapGenerator.server.lua

    This script runs automatically on server startup. It procedurally generates a map
    and places it into ServerStorage/Maps, making it available for the GameManager
    to load during a round. This avoids the need for storing a separate .rbxmx file.
]]

local ServerStorage = game:GetService("ServerStorage")

-- Configuration for the generated map
local MAP_CONFIG = {
    Name = "GeneratedProceduralMap",
    Size = Vector3.new(300, 100, 300),
    FloorThickness = 2,
    WallHeight = 15,
    NumWalls = 50,
    MinWallLength = 20,
    MaxWallLength = 80,
    WallThickness = 4,
    Seed = 12346
}

-- Main function to build the map
local function buildAndPlaceMap()
    -- 1. Ensure the 'Maps' folder exists in ServerStorage
    local mapsFolder = ServerStorage:FindFirstChild("Maps")
    if not mapsFolder then
        mapsFolder = Instance.new("Folder")
        mapsFolder.Name = "Maps"
        mapsFolder.Parent = ServerStorage
        print("[MapGenerator] Created 'Maps' folder in ServerStorage.")
    end

    -- 2. Check if this map has already been generated to prevent duplicates during live-sync
    if mapsFolder:FindFirstChild(MAP_CONFIG.Name) then
        print("[MapGenerator] Map '" .. MAP_CONFIG.Name .. "' already exists in ServerStorage. Skipping generation.")
        return
    end

    -- 3. Create a new model for the map
    local mapModel = Instance.new("Model")
    mapModel.Name = MAP_CONFIG.Name

    -- Set the random seed for deterministic generation
    math.randomseed(MAP_CONFIG.Seed)

    -- 4. Create the floor
    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(MAP_CONFIG.Size.X, MAP_CONFIG.FloorThickness, MAP_CONFIG.Size.Z)
    floor.Position = Vector3.new(0, -MAP_CONFIG.FloorThickness / 2, 0)
    floor.Anchored = true
    floor.BrickColor = BrickColor.new("Dark stone grey")
    floor.Material = Enum.Material.Concrete
    floor.Parent = mapModel

    -- Set the floor as the PrimaryPart for easy positioning
    mapModel.PrimaryPart = floor

    -- 5. Create random walls
    for i = 1, MAP_CONFIG.NumWalls do
        local wall = Instance.new("Part")
        wall.Name = "Wall" .. i
        wall.Anchored = true
        wall.BrickColor = BrickColor.new("Institutional white")
        wall.Material = Enum.Material.Brick

        local isHorizontal = (math.random() > 0.5)
        local length = math.random(MAP_CONFIG.MinWallLength, MAP_CONFIG.MaxWallLength)

        if isHorizontal then
            wall.Size = Vector3.new(length, MAP_CONFIG.WallHeight, MAP_CONFIG.WallThickness)
        else
            wall.Size = Vector3.new(MAP_CONFIG.WallThickness, MAP_CONFIG.WallHeight, length)
        end

        -- Calculate a random position within the map bounds
        local halfMapX = MAP_CONFIG.Size.X / 2 - length / 2
        local halfMapZ = MAP_CONFIG.Size.Z / 2 - length / 2

        local randomX = math.random(-halfMapX, halfMapX)
        local randomZ = math.random(-halfMapZ, halfMapZ)

        wall.Position = Vector3.new(
            randomX,
            MAP_CONFIG.WallHeight / 2,
            randomZ
        )

        wall.Parent = mapModel
    end

    -- 6. Create Boundary Walls to enclose the map
    local halfX = MAP_CONFIG.Size.X / 2
    local halfZ = MAP_CONFIG.Size.Z / 2
    local wallHeight = MAP_CONFIG.WallHeight
    local wallThickness = MAP_CONFIG.WallThickness

    local wallProperties = {
        North = {
            Size = Vector3.new(MAP_CONFIG.Size.X + wallThickness, wallHeight, wallThickness),
            Position = Vector3.new(0, wallHeight / 2, -halfZ)
        },
        South = {
            Size = Vector3.new(MAP_CONFIG.Size.X + wallThickness, wallHeight, wallThickness),
            Position = Vector3.new(0, wallHeight / 2, halfZ)
        },
        East = {
            Size = Vector3.new(wallThickness, wallHeight, MAP_CONFIG.Size.Z),
            Position = Vector3.new(halfX, wallHeight / 2, 0)
        },
        West = {
            Size = Vector3.new(wallThickness, wallHeight, MAP_CONFIG.Size.Z),
            Position = Vector3.new(-halfX, wallHeight / 2, 0)
        }
    }

    for name, props in pairs(wallProperties) do
        local wall = Instance.new("Part")
        wall.Name = "BoundaryWall_" .. name
        wall.Size = props.Size
        wall.Position = props.Position
        wall.Anchored = true
        wall.BrickColor = BrickColor.new("Dark stone grey")
        wall.Material = Enum.Material.Concrete
        wall.Parent = mapModel
    end

    -- 7. Parent the finished model to the Maps folder
    mapModel.Parent = mapsFolder
    print("[MapGenerator] Successfully generated and stored map: '" .. MAP_CONFIG.Name .. "'.")
end

-- Run the build function
buildAndPlaceMap()