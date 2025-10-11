--[[
	MapGenerator.module.lua

	Procedurally generates a multi-room map based on a high-level layout configuration.
	This script is designed to be the single source of truth for the map's structure.

	The generator will:
	1. Read the LAYOUT configuration table.
	2. Generate 3D models for each room and corridor.
	3. Position the rooms and corridors in the workspace.
	4. Spawn gameplay objects (spawns, machines, etc.) within the rooms.
	5. Assemble the final map and save it to ServerStorage for the GameManager to use.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MapGenerator = {}

--================================================================
-- CONFIGURATION
-- Edit these values to change the generated map's properties.
--================================================================
local CONFIG = {
	MAP_NAME = "MurkyWaterFishbowl",

	-- Room properties
	LARGE_ROOM_RADIUS = 100,
	SMALL_ROOM_RADIUS = 50,
	ROOM_HEIGHT = 20,
	WALL_THICKNESS = 4,

	-- Corridor properties
	CORRIDOR_WIDTH = 20,
	CORRIDOR_HEIGHT = 15,

	-- Object spawn settings
	MACHINE_SPAWN_OFFSET = 10, -- How far from the wall to spawn machines
	SHOP_SPAWN_OFFSET = 15,
}

--================================================================
-- LAYOUT DEFINITION
-- This table is the blueprint for the map. It defines each room and its connections.
-- 'Id' must be unique for each room.
-- 'Position' is the center of the room in 3D space.
-- 'Connections' lists the Ids of the rooms this room should connect to.
-- 'Objects' defines the gameplay elements to spawn within the room.
--     - Type: The kind of object to spawn.
--     - Angle: The position on the circle (0-360 degrees).
--     - Distance: The distance from the room's center.
--     - RotationY: (Optional) The object's rotation on the Y axis.
--================================================================
local LAYOUT = {
	-- The central large room
	{
		Id = "CenterRoom",
		Type = "LargeCircle",
		Position = Vector3.new(0, 0, 0),
		Connections = {"TopLeftRoom", "TopRightRoom", "BottomLeftRoom", "BottomRightRoom"},
		Objects = {
			{ Type = "KillerSpawn", Angle = 0, Distance = 0 },
			{ Type = "SurvivorSpawn", Angle = 45, Distance = 30 },
			{ Type = "KillerHanger", Angle = 90, Distance = 85 },
			{ Type = "KillerHanger", Angle = 180, Distance = 85 },
			{ Type = "KillerHanger", Angle = 270, Distance = 85 },
			{ Type = "Machine", Angle = 135, Distance = 70, RotationY = 45 },
			{ Type = "Machine", Angle = 225, Distance = 70, RotationY = -45 },
			{ Type = "Machine", Angle = 315, Distance = 70, RotationY = -135 },
			{ Type = "Shop", Angle = 60, Distance = 90, RotationY = -30 },
			{ Type = "Shop", Angle = 200, Distance = 90, RotationY = -110 },
		}
	},

	-- Surrounding smaller rooms
	{
		Id = "TopLeftRoom",
		Type = "SmallCircle",
		Position = Vector3.new(-150, 0, -150),
		Connections = {"CenterRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 30, Distance = 20 },
			{ Type = "SurvivorSpawn", Angle = 330, Distance = 20 },
			{ Type = "Machine", Angle = 180, Distance = 35, RotationY = 90 },
			{ Type = "Machine", Angle = 90, Distance = 35, RotationY = 0 },
			{ Type = "KillerHanger", Angle = 270, Distance = 40 },
			{ Type = "Shop", Angle = 225, Distance = 40, RotationY = 135 },
		}
	},
	{
		Id = "TopRightRoom",
		Type = "SmallCircle",
		Position = Vector3.new(150, 0, -150),
		Connections = {"CenterRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 0, Distance = 0 },
			{ Type = "Machine", Angle = 270, Distance = 35, RotationY = 180 },
			{ Type = "Shop", Angle = 45, Distance = 40, RotationY = -45 },
		}
	},
	{
		Id = "BottomLeftRoom",
		Type = "SmallCircle",
		Position = Vector3.new(-150, 0, 150),
		Connections = {"CenterRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 150, Distance = 25 },
			{ Type = "SurvivorSpawn", Angle = 210, Distance = 25 },
			{ Type = "Machine", Angle = 0, Distance = 35, RotationY = -90 },
			{ Type = "KillerHanger", Angle = 90, Distance = 40 },
		}
	},
	{
		Id = "BottomRightRoom",
		Type = "SmallCircle",
		Position = Vector3.new(150, 0, 150),
		Connections = {"CenterRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 180, Distance = 0 },
			{ Type = "Machine", Angle = 45, Distance = 35, RotationY = -45 },
			{ Type = "Machine", Angle = 315, Distance = 35, RotationY = 45 },
			{ Type = "KillerHanger", Angle = 270, Distance = 40 },
			{ Type = "Shop", Angle = 135, Distance = 40, RotationY = -135 },
		}
	},
}

--================================================================
-- PRIVATE GENERATION FUNCTIONS
--================================================================

local function createRoomPart(roomInfo)
	print("Generating room:", roomInfo.Id)

	local roomModel = Instance.new("Model")
	roomModel.Name = roomInfo.Id
	roomModel.PrimaryPart = nil -- Will be set to the floor

	local radius = 0
	if roomInfo.Type == "LargeCircle" then
		radius = CONFIG.LARGE_ROOM_RADIUS
	elseif roomInfo.Type == "SmallCircle" then
		radius = CONFIG.SMALL_ROOM_RADIUS
	else
		warn("Unknown room type:", roomInfo.Type)
		return nil
	end

	-- Create the floor
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

	-- Create the walls using segments
	local numWallSegments = 36 -- More segments = smoother circle
	local segmentAngle = 360 / numWallSegments

	for i = 1, numWallSegments do
		local angle = math.rad(i * segmentAngle)
		local x = roomInfo.Position.X + radius * math.cos(angle)
		local z = roomInfo.Position.Z + radius * math.sin(angle)

		local segment = Instance.new("Part")
		segment.Name = "WallSegment"
		segment.Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, (2 * math.pi * radius) / numWallSegments + 1)
		segment.Position = Vector3.new(x, roomInfo.Position.Y + CONFIG.ROOM_HEIGHT / 2, z)
		segment.Orientation = Vector3.new(0, -i * segmentAngle, 0)
		segment.Anchored = true
		segment.Color = Color3.fromRGB(100, 100, 100)
		segment.Parent = roomModel
	end

	return roomModel
end

local function createCorridorPart(roomA, roomB)
	print("Generating corridor between:", roomA.Id, "and", roomB.Id)

	local posA = roomA.Position
	local posB = roomB.Position

	local distance = (posA - posB).Magnitude
	local midPoint = posA:Lerp(posB, 0.5)

	local angle = math.atan2(posB.X - posA.X, posB.Z - posA.Z)
	local orientation = Vector3.new(0, math.deg(angle), 0)

	local corridor = Instance.new("Part")
	corridor.Name = "Corridor"
	corridor.Size = Vector3.new(CONFIG.CORRIDOR_WIDTH, CONFIG.CORRIDOR_HEIGHT, distance)
	corridor.Position = midPoint
	corridor.Orientation = orientation
	corridor.Anchored = true
	corridor.Color = Color3.fromRGB(60, 60, 60)
	corridor.Parent = nil -- Will be parented by the main Generate function

	return corridor
end

local function spawnObjectsInRoom(roomModel, roomInfo)
	print("Spawning objects in room:", roomInfo.Id)

	local assetsFolder = ServerStorage:FindFirstChild("Assets")
	if not assetsFolder then
		warn("[MapGenerator] Cannot spawn objects: 'Assets' folder not found in ServerStorage.")
		return
	end

	local roomCenter = roomInfo.Position

	if not roomInfo.Objects then
		return
	end

	for _, objectInfo in ipairs(roomInfo.Objects) do
		local angle = math.rad(objectInfo.Angle)
		local distance = objectInfo.Distance

		local x = roomCenter.X + distance * math.cos(angle)
		local z = roomCenter.Z + distance * math.sin(angle)
		local y = roomCenter.Y + 2 -- Default height, can be adjusted per object

		local position = Vector3.new(x, y, z)
		local orientation = Vector3.new(0, objectInfo.RotationY or 0, 0)

		local newObject = nil

		if objectInfo.Type == "KillerSpawn" or objectInfo.Type == "SurvivorSpawn" then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = objectInfo.Type
			spawn.Position = position
			spawn.Anchored = true
			spawn.Size = Vector3.new(5, 1, 5)
			spawn.Transparency = 0.5
			spawn.Neutral = false
			spawn.TeamColor = objectInfo.Type == "KillerSpawn" and BrickColor.new("Really red") or BrickColor.new("Bright blue")
			newObject = spawn
		else
			-- Handle clonable assets like Machines, Shops, Hangers
			local templateName = objectInfo.Type .. "Template"
			local template = assetsFolder:FindFirstChild(templateName)

			if template then
				newObject = template:Clone()
				newObject.Name = objectInfo.Type

				if newObject:IsA("Model") and newObject.PrimaryPart then
					newObject:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(orientation.Y), 0))
				else
					newObject.Position = position
					newObject.Orientation = orientation
				end
			else
				warn(string.format("[MapGenerator] Asset template '%s' not found in ServerStorage/Assets.", templateName))
			end
		end

		if newObject then
			newObject.Parent = roomModel
		end
	end
end

--================================================================
-- PUBLIC API
--================================================================

function MapGenerator.Generate()
	print("Starting procedural map generation...")

	local mapModel = Instance.new("Model")
	mapModel.Name = CONFIG.MAP_NAME

	local generatedRooms = {}

	-- Step 1: Create all the rooms
	for _, roomInfo in ipairs(LAYOUT) do
		local roomPart = createRoomPart(roomInfo)
		if roomPart then
			roomPart.Parent = mapModel
			generatedRooms[roomInfo.Id] = {Info = roomInfo, Part = roomPart}
		end
	end

	-- Step 2: Create corridors to connect the rooms
	local connectedPairs = {}
	for _, roomInfo in ipairs(LAYOUT) do
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

	-- Step 3: Spawn objects within each room
	for _, roomData in pairs(generatedRooms) do
		spawnObjectsInRoom(roomData.Part, roomData.Info)
	end

	-- Step 4: Finalize and save the map
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
