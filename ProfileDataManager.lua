local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)
local DataSyncManager = require(script.Parent.DataSyncManager)

local ProfileDataManager = {}

local PROFILE_STORE_NAME = "OrbTutorialData"
local PROFILE_VERSION = "v1"

local ProfileTemplate = {
	HasOrb = false,
	FirstJoin = 0,
	LastSave = 0,
}

local Profiles = {}

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, ProfileTemplate)

function ProfileDataManager.Initialize()
	Players.PlayerAdded:Connect(function(player)
		ProfileDataManager.LoadPlayerProfile(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		ProfileDataManager.SaveAndReleaseProfile(player)
	end)
	
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			ProfileDataManager.SaveAndReleaseProfile(player)
		end
		task.wait(2)
	end)
end

function ProfileDataManager.LoadPlayerProfile(player)
	local userId = player.UserId
	local profileKey = tostring(userId)
	
	local profile = ProfileStore:LoadProfileAsync(profileKey, "ForceLoad")
	
	if not profile then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end
	
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end
	
	Profiles[userId] = profile
	
	if profile.Data.FirstJoin == 0 then
		profile.Data.FirstJoin = os.time()
	end
	
	profile:Reconcile()
	
	profile:ListenToRelease(function()
		Profiles[userId] = nil
		player.Kick("Your data was loaded on another server.")
	end)
	
	DataSyncManager.SyncAllFromDataStore(player.profile.Data)
	
	ProfileDataManager.StartAutoSave(player)
end

function ProfileDataManager.SaveAndReleaseProfile(player)
	local profile = Profiles[player.UserId]
	if not profile then return end
	
	DataSyncManager.SyncAllToDataStore(player, profile.Data)
	
	profile.Data.LastSave = os.time()
	
	profile:Release()
	Profiles[player.UserId] = nil
end

function ProfileDataManager.UpdateData(player, key, value)
	local profile = Profiles[player.UserId]
	if profile and profile:IsActive() then
		profile.Data[key] = value
		return true
	end
	return false
end

function ProfileDataManager.StartAutoSave(player)
	task.spawn(function()
		while player:IsDescendantOf(Players) and Profiles[player.UserId]  do
			task.wait(120)
			local profile = Profiles[player.UserId]
			if profile and profile:IsActive() then
DataSyncManager.SyncAllToDataStore(player, profile.Data)
profile.Data.LastSave = os.time()
			end
		end
	end)
end

return ProfileDataManager
