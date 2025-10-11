--[[
	MapGenerator.lua

	Procedurally generates a multi-room map based on a high-level layout configuration.
	This script is designed to be the single source of truth for the map's structure.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MapGenerator = {}

--================================================================
-- CONFIGURATION
--================================================================
local CONFIG = {
	MAP_NAME = "MurkyWaterFishbowl",
	LARGE_ROOM_RADIUS = 100,
	SMALL_ROOM_RADIUS = 50,
	ROOM_HEIGHT = 20,
	WALL_THICKNESS = 4,
	CORRIDOR_WIDTH = 20,
	CORRIDOR_HEIGHT = 5,
}

--================================================================
-- LAYOUT DEFINITION
--================================================================

-- 5-Room Layout Constants
local MAP_HALF_SIZE = 225
local CORNER_SIZE_VAL = 150
local CORNER_SIZE = Vector3.new(CORNER_SIZE_VAL, CONFIG.ROOM_HEIGHT, CORNER_SIZE_VAL)
local CORNER_OFFSET = MAP_HALF_SIZE - (CORNER_SIZE_VAL / 2)
local CENTER_SIZE_VAL = (MAP_HALF_SIZE * 2) - (CORNER_SIZE_VAL * 2)
local CENTER_SIZE = Vector3.new(CENTER_SIZE_VAL, CONFIG.ROOM_HEIGHT, CENTER_SIZE_VAL)

-- Grid-based positions for spawn points (relative to room center)
local SPAWN_GRID_STEP = 75
local SPAWN_GRID_OFFSET = -SPAWN_GRID_STEP * 1.5

local function getSpawnPos(row, col)
	return Vector3.new(SPAWN_GRID_OFFSET + col * SPAWN_GRID_STEP, 2, SPAWN_GRID_OFFSET + row * SPAWN_GRID_STEP)
end

local LAYOUT = {
	-- The central large room
	{
		Id = "CenterRoom", Type = "Rectangle", Position = Vector3.new(0, 0, 0), Size = CENTER_SIZE,
		Connections = {"TopLeftRoom", "TopRightRoom", "BottomLeftRoom", "BottomRightRoom"},
		PotentialSpawns = {
			Survivor = { getSpawnPos(1, 1), getSpawnPos(2, 2) }, -- F, K
			Killer = { getSpawnPos(2, 1), getSpawnPos(1, 2) }, -- J, G
			Machine = { getSpawnPos(0, 1), getSpawnPos(0, 2), getSpawnPos(1, 0), getSpawnPos(1, 3), getSpawnPos(2, 0), getSpawnPos(2, 3), getSpawnPos(3, 1), getSpawnPos(3, 2) }, -- B, C, E, H, I, L, N, O
			Hanger = { Vector3.new(-100, 2, 0), Vector3.new(100, 2, 0), Vector3.new(0, 2, -100), Vector3.new(0, 2, 100) },
			StoreKeeper = { Vector3.new(0, 2, 0) },
			CoinStash = { Vector3.new(-30, 2, -30), Vector3.new(30, 2, -30), Vector3.new(-30, 2, 30), Vector3.new(30, 2, 30) }
		}
	},
	-- Surrounding smaller rooms
	{
		Id = "TopLeftRoom", Type = "Rectangle", Position = Vector3.new(-CORNER_OFFSET, 0, -CORNER_OFFSET), Size = CORNER_SIZE,
		Connections = {"CenterRoom"},
		PotentialSpawns = { Survivor = { Vector3.new(0, 2, 0) } } -- A
	},
	{
		Id = "TopRightRoom", Type = "Rectangle", Position = Vector3.new(CORNER_OFFSET, 0, -CORNER_OFFSET), Size = CORNER_SIZE,
		Connections = {"CenterRoom"},
		PotentialSpawns = { Survivor = { Vector3.new(0, 2, 0) } } -- D
	},
	{
		Id = "BottomLeftRoom", Type = "Rectangle", Position = Vector3.new(-CORNER_OFFSET, 0, CORNER_OFFSET), Size = CORNER_SIZE,
		Connections = {"CenterRoom"},
		PotentialSpawns = { Survivor = { Vector3.new(0, 2, 0) } } -- M
	},
	{
		Id = "BottomRightRoom", Type = "Rectangle", Position = Vector3.new(CORNER_OFFSET, 0, CORNER_OFFSET), Size = CORNER_SIZE,
		Connections = {"CenterRoom"},
		PotentialSpawns = { Survivor = { Vector3.new(0, 2, 0) } } -- P
	},
    -- Victory gates are not tied to a room, defined here for generation
    { Id = "VictoryGate_1", Type="Gate", Position = Vector3.new(0, 2, MAP_HALF_SIZE + 20) },
    { Id = "VictoryGate_2", Type="Gate", Position = Vector3.new(0, 2, -MAP_HALF_SIZE - 20) }
}

--================================================================
-- ASSET CREATION (Private)
--================================================================
local function createPlaceholderAssets()
	local assetsFolder = ServerStorage:FindFirstChild("Assets")
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "Assets"
		assetsFolder.Parent = ServerStorage
		print("[MapGenerator] Created 'Assets' folder in ServerStorage.")
	end

	local function createTemplate(name, size)
		if not assetsFolder:FindFirstChild(name) then
			local model = Instance.new("Model")
			model.Name = name
			local part = Instance.new("Part")
			part.Name = "PlaceholderPart"
			part.Size = size
			part.Anchored = true
			part.Parent = model
			model.PrimaryPart = part
			model.Parent = assetsFolder
			print(string.format("[MapGenerator] Created placeholder asset: %s", name))
		end
	end

	createTemplate("MachineTemplate", Vector3.new(4, 6, 4))
	createTemplate("ShopTemplate", Vector3.new(8, 10, 8))
	createTemplate("KillerHangerTemplate", Vector3.new(3, 12, 3))
end

--================================================================
-- GEOMETRY GENERATION (Private)
--================================================================

local function createRectangleRoomPart(roomInfo)
	local roomModel = Instance.new("Model")
	roomModel.Name = roomInfo.Id

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Block
	floor.Size = roomInfo.Size
	floor.Position = roomInfo.Position
	floor.Anchored = true
	floor.Color = Color3.fromRGB(100, 100, 100)
	floor.Parent = roomModel
	roomModel.PrimaryPart = floor

	-- Create walls around the rectangle room
	local wallPositions = {
		{Name = "Wall_N", Position = Vector3.new(0, 0, -roomInfo.Size.Z / 2), Size = Vector3.new(roomInfo.Size.X, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS)},
		{Name = "Wall_S", Position = Vector3.new(0, 0, roomInfo.Size.Z / 2), Size = Vector3.new(roomInfo.Size.X, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS)},
		{Name = "Wall_E", Position = Vector3.new(roomInfo.Size.X / 2, 0, 0), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, roomInfo.Size.Z)},
		{Name = "Wall_W", Position = Vector3.new(-roomInfo.Size.X / 2, 0, 0), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, roomInfo.Size.Z)},
	}

	for _, wallInfo in ipairs(wallPositions) do
		local wall = Instance.new("Part")
		wall.Name = wallInfo.Name
		wall.Size = wallInfo.Size
		wall.Position = roomInfo.Position + wallInfo.Position
		wall.Anchored = true
		wall.Color = Color3.fromRGB(120, 120, 120)
		wall.Parent = roomModel
	end


	return roomModel
end

local function createRoomPart(roomInfo, allRoomsLayout)
	if roomInfo.Type == "Rectangle" then
		return createRectangleRoomPart(roomInfo)
	end
	-- Note: Circle room generation is no longer used by the new layout but is kept for potential future use.
	local roomModel = Instance.new("Model")
	roomModel.Name = roomInfo.Id
	local radius = roomInfo.Type == "LargeCircle" and CONFIG.LARGE_ROOM_RADIUS or CONFIG.SMALL_ROOM_RADIUS
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(CONFIG.WALL_THICKNESS, radius * 2, radius * 2)
	floor.Position = roomInfo.Position
	floor.Orientation = Vector3.new(0, 0, 90)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(80, 80, 80)
	floor.Parent = roomModel
	roomModel.PrimaryPart = floor
	return roomModel
end

local function createCorridorPart(roomA, roomB)
	local posA = roomA.Position
	local posB = roomB.Position
	local distance = (posA - posB).Magnitude
	local midPoint = posA:Lerp(posB, 0.5)
	local angle = math.atan2(posB.X - posA.X, posB.Z - posA.Z)

	local corridor = Instance.new("Part")
	corridor.Name = "Corridor"
	corridor.Size = Vector3.new(CONFIG.CORRIDOR_WIDTH, CONFIG.CORRIDOR_HEIGHT, distance)
	corridor.Position = Vector3.new(midPoint.X, roomA.Position.Y, midPoint.Z)
	corridor.Orientation = Vector3.new(0, math.deg(angle), 0)
	corridor.Anchored = true
	corridor.Color = Color3.fromRGB(60, 60, 60)

	return corridor
end

--================================================================
-- SPAWN POINT GENERATION (Private)
--================================================================
local function createPotentialSpawnPoints(mapModel, allRoomsLayout)
	local spawnsRoot = Instance.new("Folder", mapModel)
	spawnsRoot.Name = "PotentialSpawns"

	-- Handle special case for Victory Gates not in a room
	for _, itemInfo in ipairs(allRoomsLayout) do
		if itemInfo.Type == "Gate" then
			local typeFolder = spawnsRoot:FindFirstChild("VictoryGate") or Instance.new("Folder", spawnsRoot)
			typeFolder.Name = "VictoryGate"
			local spawnPoint = Instance.new("Part")
			spawnPoint.Name = itemInfo.Id
			spawnPoint.Size = Vector3.new(4, 1, 4)
			spawnPoint.Anchored = true
			spawnPoint.CanCollide = false
			spawnPoint.Transparency = 0.5
			spawnPoint.Color = Color3.fromRGB(255, 255, 0)
			spawnPoint.Position = itemInfo.Position
			spawnPoint.Parent = typeFolder
		end
	end

	for _, roomInfo in ipairs(allRoomsLayout) do
		if roomInfo.PotentialSpawns then
			for spawnType, positions in pairs(roomInfo.PotentialSpawns) do
				local typeFolder = spawnsRoot:FindFirstChild(spawnType) or Instance.new("Folder", spawnsRoot)
				typeFolder.Name = spawnType

				for i, pos in ipairs(positions) do
					local spawnPoint = Instance.new("Part")
					spawnPoint.Name = roomInfo.Id .. "_" .. spawnType .. "_" .. i
					spawnPoint.Size = Vector3.new(4, 1, 4)
					spawnPoint.Anchored = true
					spawnPoint.CanCollide = false
					spawnPoint.Transparency = 0.5
					-- Position is relative to room center, so add them
					spawnPoint.Position = roomInfo.Position + pos
					spawnPoint.Parent = typeFolder
				end
			end
		end
	end
end


--================================================================
-- PUBLIC API
--================================================================
function MapGenerator.Generate()
	print("Starting procedural map generation...")

	-- Step 1: Ensure placeholder assets exist
	createPlaceholderAssets()

	local mapModel = Instance.new("Model")
	mapModel.Name = CONFIG.MAP_NAME

	local generatedRooms = {}

	-- Step 2: Create all the rooms
	for _, roomInfo in ipairs(LAYOUT) do
        if roomInfo.Type ~= "Gate" then
		    local roomPart = createRoomPart(roomInfo, LAYOUT)
		    if roomPart then
			    roomPart.Parent = mapModel
			    generatedRooms[roomInfo.Id] = {Info = roomInfo, Part = roomPart}
		    end
        end
	end

	-- Step 3: Create corridors to connect the rooms
	local connectedPairs = {}
	for _, roomInfo in ipairs(LAYOUT) do
		if roomInfo.Connections then
			for _, targetId in ipairs(roomInfo.Connections) do
				local pairKey = table.concat({roomInfo.Id, targetId}, "-")
				local reversePairKey = table.concat({targetId, roomInfo.Id}, "-")

				if not connectedPairs[pairKey] and not connectedPairs[reversePairKey] then
					local roomA = generatedRooms[roomInfo.Id]
					local roomB = generatedRooms[targetId]
					if roomA and roomB then
						local corridorPart = createCorridorPart(roomA.Info, roomB.Info)
						if corridorPart then
							corridorPart.Parent = mapModel
						end
						connectedPairs[pairKey] = true
					end
				end
			end
		end
	end

	-- Step 4: Create all potential spawn point markers
	createPotentialSpawnPoints(mapModel, LAYOUT)

	-- Step 5: Finalize and save the map
	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	if not mapsFolder then
		mapsFolder = Instance.new("Folder")
		mapsFolder.Name = "Maps"
		mapsFolder.Parent = ServerStorage
	end

	mapModel.Parent = mapsFolder
	print("Procedural map generation complete! Saved to ServerStorage/Maps/" .. CONFIG.MAP_NAME)

	return mapModel
end

return MapGenerator
