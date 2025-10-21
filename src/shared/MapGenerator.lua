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
		Id = "TopLeftRoom", Type = "SmallCircle", Position = Vector3.new(-150, 0, -150), Connections = {"CenterRoom", "TopRightRoom", "BottomLeftRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 30, Distance = 20 }, { Type = "SurvivorSpawn", Angle = 330, Distance = 20 },
			{ Type = "Machine", Angle = 180, Distance = 35, RotationY = 90 }, { Type = "Machine", Angle = 90, Distance = 35, RotationY = 0 },
			{ Type = "KillerHanger", Angle = 270, Distance = 40 }, { Type = "Shop", Angle = 225, Distance = 40, RotationY = 135 },
		}
	},
	{
		Id = "TopRightRoom", Type = "SmallCircle", Position = Vector3.new(150, 0, -150), Connections = {"CenterRoom", "TopLeftRoom", "BottomRightRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 0, Distance = 0 }, { Type = "Machine", Angle = 270, Distance = 35, RotationY = 180 },
			{ Type = "Shop", Angle = 45, Distance = 40, RotationY = -45 },
		}
	},
	{
		Id = "BottomLeftRoom", Type = "SmallCircle", Position = Vector3.new(-150, 0, 150), Connections = {"CenterRoom", "TopLeftRoom", "BottomRightRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 150, Distance = 25 }, { Type = "SurvivorSpawn", Angle = 210, Distance = 25 },
			{ Type = "Machine", Angle = 0, Distance = 35, RotationY = -90 }, { Type = "KillerHanger", Angle = 90, Distance = 40 },
		}
	},
	{
		Id = "BottomRightRoom", Type = "SmallCircle", Position = Vector3.new(150, 0, 150), Connections = {"CenterRoom", "BottomLeftRoom", "TopRightRoom"},
		Objects = {
			{ Type = "SurvivorSpawn", Angle = 180, Distance = 0 },
			{ Type = "Machine", Angle = 45, Distance = 35, RotationY = -45 }, { Type = "Machine", Angle = 315, Distance = 35, RotationY = 45 },
			{ Type = "KillerHanger", Angle = 270, Distance = 40 }, { Type = "Shop", Angle = 135, Distance = 40, RotationY = -135 },
		}
	},
	-- Individual Outer Wall Segments
	{ Id = "OuterWall_1", Type = "Rectangle", Position = Vector3.new(-200, 0, -275), Size = Vector3.new(100, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS), Connections = {} },
	{ Id = "OuterWall_2", Type = "Rectangle", Position = Vector3.new(200, 0, -275), Size = Vector3.new(100, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS), Connections = {} },
	{ Id = "OuterWall_3", Type = "Rectangle", Position = Vector3.new(-250, 0, -200), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, 150), Connections = {} },
	{ Id = "OuterWall_4", Type = "Rectangle", Position = Vector3.new(250, 0, -200), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, 150), Connections = {} },
	{ Id = "OuterWall_5", Type = "Rectangle", Position = Vector3.new(-200, 0, 275), Size = Vector3.new(100, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS), Connections = {} },
	{ Id = "OuterWall_6", Type = "Rectangle", Position = Vector3.new(200, 0, 275), Size = Vector3.new(100, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS), Connections = {} },
	{ Id = "OuterWall_7", Type = "Rectangle", Position = Vector3.new(-250, 0, 200), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, 150), Connections = {} },
	{ Id = "OuterWall_8", Type = "Rectangle", Position = Vector3.new(250, 0, 200), Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, 150), Connections = {} },
	{ Id = "OuterWall_9", Type = "Rectangle", Position = Vector3.new(0, 0, 325), Size = Vector3.new(150, CONFIG.ROOM_HEIGHT, CONFIG.WALL_THICKNESS), Connections = {} },
}

--================================================================
-- ASSET CREATION (Private)
-- Ensures the generator can run even in a clean environment.
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

	return roomModel
end

local function createRoomPart(roomInfo, allRoomsLayout)
	if roomInfo.Type == "Rectangle" then
		return createRectangleRoomPart(roomInfo)
	end

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

	-- Calculate angles for corridor openings
	local openingAngles = {}
	if roomInfo.Connections then
		for _, targetId in ipairs(roomInfo.Connections) do
			for _, room in ipairs(allRoomsLayout) do
				if room.Id == targetId then
					local angle = math.atan2(room.Position.Z - roomInfo.Position.Z, room.Position.X - roomInfo.Position.X)
					table.insert(openingAngles, math.deg(angle))
				end
			end
		end
	end

	local numWallSegments = 36
	local segmentAngle = 360 / numWallSegments
	local openingWidthInDegrees = math.deg(math.atan2(CONFIG.CORRIDOR_WIDTH / 2, radius)) * 2

	for i = 1, numWallSegments do
		local currentAngle = i * segmentAngle

		local isOpening = false
		for _, openingAngle in ipairs(openingAngles) do
			local angleDifference = math.abs(currentAngle - openingAngle)
			if angleDifference > 180 then
				angleDifference = 360 - angleDifference
			end
			if angleDifference < (openingWidthInDegrees / 2) then
				isOpening = true
				break
			end
		end

		if not isOpening then
			local angleRad = math.rad(currentAngle)
			local x = roomInfo.Position.X + radius * math.cos(angleRad)
			local z = roomInfo.Position.Z + radius * math.sin(angleRad)

			local segment = Instance.new("Part")
			segment.Name = "WallSegment"
			segment.Size = Vector3.new(CONFIG.WALL_THICKNESS, CONFIG.ROOM_HEIGHT, (2 * math.pi * radius) / numWallSegments + 1.5) -- Add overlap
			segment.Position = Vector3.new(x, roomInfo.Position.Y + CONFIG.ROOM_HEIGHT / 2, z)
			segment.Orientation = Vector3.new(0, -currentAngle, 0)
			segment.Anchored = true
			segment.Color = Color3.fromRGB(100, 100, 100)
			segment.Parent = roomModel
		end
	end

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
-- OBJECT SPAWNING (Private)
--================================================================
local function spawnObjectsInRoom(roomModel, roomInfo)
	local assetsFolder = ServerStorage:FindFirstChild("Assets")
	local roomCenter = roomInfo.Position

	if not roomInfo.Objects then return end

	for _, objectInfo in ipairs(roomInfo.Objects) do
		local angle = math.rad(objectInfo.Angle)
		local distance = objectInfo.Distance

		local x = roomCenter.X + distance * math.cos(angle)
		local z = roomCenter.Z + distance * math.sin(angle)
		local y = roomCenter.Y + 2

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

	-- Step 1: Ensure placeholder assets exist
	createPlaceholderAssets()

	local mapModel = Instance.new("Model")
	mapModel.Name = CONFIG.MAP_NAME

	local generatedRooms = {}

	-- Step 2: Create all the rooms
	for _, roomInfo in ipairs(LAYOUT) do
		local roomPart = createRoomPart(roomInfo, LAYOUT)
		if roomPart then
			roomPart.Parent = mapModel
			generatedRooms[roomInfo.Id] = {Info = roomInfo, Part = roomPart}
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

	-- Step 4: Spawn objects within each room
	for _, roomData in pairs(generatedRooms) do
		spawnObjectsInRoom(roomData.Part, roomData.Info)
	end

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
