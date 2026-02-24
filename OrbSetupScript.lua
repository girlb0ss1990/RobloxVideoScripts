-- FULL ORB SYSTEM REBUILD (Command Bar Script)
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- 0. CLEANUP (Deletes old versions to prevent duplicates)
if workspace:FindFirstChild("KindnessOrb") then workspace.KindnessOrb:Destroy() end
if ReplicatedStorage:FindFirstChild("OrbNetwork") then ReplicatedStorage.OrbNetwork:Destroy() end
if StarterGui:FindFirstChild("OrbGui") then StarterGui.OrbGui:Destroy() end
if ServerScriptService:FindFirstChild("OrbLogic") then ServerScriptService.OrbLogic:Destroy() end

-- 1. NETWORKING SETUP
local folder = Instance.new("Folder")
folder.Name = "OrbNetwork"
folder.Parent = ReplicatedStorage

local dataChanged = Instance.new("RemoteEvent")
dataChanged.Name = "DataChanged"
dataChanged.Parent = folder

local getData = Instance.new("RemoteFunction")
getData.Name = "GetPlayerData"
getData.Parent = folder

-- 2. THE PHYSICAL ORB
local orb = Instance.new("Part")
orb.Name = "KindnessOrb"
orb.Shape = Enum.PartType.Ball
orb.Size = Vector3.new(3, 3, 3)
orb.Position = Vector3.new(0, 5, 15)
orb.BrickColor = BrickColor.new("New Yeller")
orb.Material = Enum.Material.Neon
orb.Anchored = true
orb.Parent = workspace

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Collect Kindness"
prompt.ObjectText = "Orb"
prompt.HoldDuration = 0.5
prompt.Parent = orb

-- 3. THE UI SETUP
local sg = Instance.new("ScreenGui")
sg.Name = "OrbGui"
sg.ResetOnSpawn = false
sg.Parent = StarterGui

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 200, 0, 50)
container.Position = UDim2.new(0, 20, 0, 20)
container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
container.BorderSizePixel = 2
container.Parent = sg

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red initially
statusLabel.Text = "Orb Collected: NO"
statusLabel.TextSize = 18
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = container

-- 4. THE SERVER LOGIC (The "Brain")
local serverScript = Instance.new("Script")
serverScript.Name = "OrbLogic"
serverScript.Source = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("OrbNetwork")
local Orb = workspace:WaitForChild("KindnessOrb")

-- Mock Data Table (In a real setup, this would be your ProfileService Data)
local PlayerData = {}

-- Initialize player data on join
game.Players.PlayerAdded:Connect(function(player)
	PlayerData[player.UserId] = { HasOrb = false }
end)

-- Handle UI Requests
Network.GetPlayerData.OnServerInvoke = function(player)
	return PlayerData[player.UserId] or { HasOrb = false }
end

-- Handle Collection
Orb.ProximityPrompt.Triggered:Connect(function(player)
	local data = PlayerData[player.UserId]
	if data and not data.HasOrb then
		data.HasOrb = true
		
		-- Visual Feedback
		Orb.Transparency = 0.8
		Orb.CanCollide = false
		Orb.ProximityPrompt.Enabled = false
		
		-- Notify Client
		Network.DataChanged:FireClient(player)
		print(player.Name .. " collected the orb!")
	end
end)
]]
serverScript.Parent = ServerScriptService

-- 5. THE CLIENT LOGIC (The "Eyes")
local clientScript = Instance.new("LocalScript")
clientScript.Source = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("OrbNetwork")
local label = script.Parent

local function updateUI()
	local data = Network.GetPlayerData:InvokeServer()
	if data and data.HasOrb then
		label.Text = "Orb Collected: YES"
		label.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
	else
		label.Text = "Orb Collected: NO"
		label.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red
	end
end

Network.DataChanged.OnClientEvent:Connect(updateUI)
task.wait(1) -- Small wait to ensure server has initialized player
updateUI()
]]
clientScript.Parent = statusLabel

print("✅ COMPLETE SYSTEM REBUILT: Orb, UI, and Networking are ready!")
