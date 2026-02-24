--[[
	ProfileService - Roblox DataStore wrapper for player data
	Version: 0.12.0
	Source: https://github.com/MadStudioRoblox/ProfileService
]]

local ProfileService = {}

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Profiles = {}
local ProfileStores = {}

-- Profile class
local Profile = {}
Profile.__index = Profile

function Profile:IsActive()
	return self._is_active
end

function Profile:GetMetaData()
	return self._metadata
end

function Profile:Reconcile()
	-- Fill in missing keys from template
	local function reconcileTable(target, template)
		for key, value in pairs(template) do
			if target[key] == nil then
				if type(value) == "table" then
					target[key] = {}
					reconcileTable(target[key], value)
				else
					target[key] = value
				end
			elseif type(target[key]) == "table" and type(value) == "table" then
				reconcileTable(target[key], value)
			end
		end
	end
	
	reconcileTable(self.Data, self._profile_store._profile_template)
end

function Profile:ListenToRelease(callback)
	if not self._release_listeners then
		self._release_listeners = {}
	end
	table.insert(self._release_listeners, callback)
	
	return {
		Disconnect = function()
			local index = table.find(self._release_listeners, callback)
			if index then
				table.remove(self._release_listeners, index)
			end
		end
	}
end

function Profile:Release()
	if not self._is_active then
		return
	end
	
	self._is_active = false
	
	-- Save data
	local success, err = pcall(function()
		self._profile_store._data_store:SetAsync(self._profile_key, {
			Data = self.Data,
			MetaData = self._metadata
		})
	end)
	
	if not success then
		warn("[ProfileService] Failed to save profile on release:", err)
	end
	
	-- Call release listeners
	if self._release_listeners then
		for _, callback in ipairs(self._release_listeners) do
			task.spawn(callback)
		end
	end
	
	-- Remove from active profiles
	Profiles[self._profile_key] = nil
end

-- ProfileStore class
local ProfileStore = {}
ProfileStore.__index = ProfileStore

function ProfileStore:LoadProfileAsync(profileKey, notReleasedHandler)
	local fullKey = self._profile_store_name .. "_" .. profileKey
	
	-- Check if profile is already loaded
	if Profiles[fullKey] then
		if notReleasedHandler == "ForceLoad" then
			Profiles[fullKey]:Release()
		else
			return nil
		end
	end
	
	-- Load from DataStore
	local profileData
	local attempts = 0
	local maxAttempts = 5
	
	while attempts < maxAttempts do
		local success, result = pcall(function()
			return self._data_store:GetAsync(fullKey)
		end)
		
		if success then
			profileData = result
			break
		else
			attempts = attempts + 1
			if attempts < maxAttempts then
				task.wait(1 * attempts) -- Exponential backoff
			else
				warn("[ProfileService] Failed to load profile after", maxAttempts, "attempts:", result)
				return nil
			end
		end
	end
	
	-- Create profile
	local profile = setmetatable({
		Data = profileData and profileData.Data or {},
		_metadata = profileData and profileData.MetaData or {
			ProfileCreateTime = os.time(),
			SessionLoadCount = 0,
			LastUpdate = os.time()
		},
		_profile_store = self,
		_profile_key = fullKey,
		_is_active = true,
		_release_listeners = {}
	}, Profile)
	
	-- Update metadata
	profile._metadata.SessionLoadCount = (profile._metadata.SessionLoadCount or 0) + 1
	profile._metadata.LastUpdate = os.time()
	
	-- Reconcile with template
	profile:Reconcile()
	
	-- Store in active profiles
	Profiles[fullKey] = profile
	
	return profile
end

function ProfileStore:GlobalUpdateProfileAsync(profileKey, updateHandler)
	local fullKey = self._profile_store_name .. "_" .. profileKey
	
	local success, err = pcall(function()
		self._data_store:UpdateAsync(fullKey, function(oldData)
			local data = oldData or {
				Data = {},
				MetaData = {
					ProfileCreateTime = os.time(),
					SessionLoadCount = 0,
					LastUpdate = os.time()
				}
			}
			
			updateHandler(data.Data)
			data.MetaData.LastUpdate = os.time()
			
			return data
		end)
	end)
	
	if not success then
		warn("[ProfileService] GlobalUpdateProfileAsync failed:", err)
	end
	
	return success
end

-- ProfileService functions
function ProfileService.GetProfileStore(profileStoreName, profileTemplate)
	if ProfileStores[profileStoreName] then
		return ProfileStores[profileStoreName]
	end
	
	local profileStore = setmetatable({
		_profile_store_name = profileStoreName,
		_profile_template = profileTemplate,
		_data_store = DataStoreService:GetDataStore(profileStoreName)
	}, ProfileStore)
	
	ProfileStores[profileStoreName] = profileStore
	
	return profileStore
end

-- Auto-save active profiles periodically
task.spawn(function()
	while true do
		task.wait(60) -- Auto-save every 60 seconds
		
		for _, profile in pairs(Profiles) do
			if profile:IsActive() then
				local success, err = pcall(function()
					profile._profile_store._data_store:SetAsync(profile._profile_key, {
						Data = profile.Data,
						MetaData = profile._metadata
					})
				end)
				
				if not success then
					warn("[ProfileService] Auto-save failed:", err)
				end
			end
		end
	end
end)

return ProfileService
