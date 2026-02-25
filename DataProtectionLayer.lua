--[[
    DataProtectionLayer - Simple Orb Edition
    Ensures that "HasOrb" is valid and backed up before it hits the cloud.
]]

local DataProtectionLayer = {}
local Players = game:GetService("Players")

-- 1. SAVE MONITORING
local SaveStats = {
    TotalAttempts = 0,
    SuccessfulSaves = 0,
    FailedSaves = 0,
}

-- 2. BACKUP STORAGE
local PlayerBackups = {}

-- 3. THE VALIDATOR (The "Gatekeeper")
-- This makes sure the data isn't "garbage" before we try to save it.
local function ValidateData(playerData)
    if not playerData or type(playerData) ~= "table" then return false end
    
    -- Check if 'HasOrb' is actually a True/False value
    if type(playerData.HasOrb) ~= "boolean" then
        return false, "HasOrb is not a boolean!"
    end
    
    return true
end

-- 4. DEEP COPY (The "Cloner")
-- Used to create a backup that isn't connected to the live data.
function DataProtectionLayer.DeepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = (type(v) == "table") and DataProtectionLayer.DeepCopy(v) or v
    end
    return copy
end

-- 5. PROTECTED SAVE (The "Safety Bubble")
function DataProtectionLayer.ProtectedSave(player, playerData, syncFunction)
    SaveStats.TotalAttempts += 1
    
    -- STEP A: Create a backup in case the sync crashes
    PlayerBackups[player.UserId] = DataProtectionLayer.DeepCopy(playerData)
    
    -- STEP B: Validate the data
    local isValid, err = ValidateData(playerData)
    if not isValid then
        warn("[DataProtection] ❌ Data invalid for " .. player.Name .. ": " .. tostring(err))
        SaveStats.FailedSaves += 1
        return false
    end
    
    -- STEP C: Run the sync function inside a pcall (Protected Call)
    -- This ensures that if DataSyncManager crashes, the whole server doesn't!
    local success, syncError = pcall(function()
        return syncFunction(player, playerData)
    end)
    
    if success then
        SaveStats.SuccessfulSaves += 1
        return true
    else
        warn("[DataProtection] ❌ Sync Error for " .. player.Name .. ": " .. tostring(syncError))
        SaveStats.FailedSaves += 1
        return false
    end
end

-- 6. HEALTH CHECK (For your Video/Console)
function DataProtectionLayer.HealthCheck()
    local rate = (SaveStats.SuccessfulSaves / math.max(1, SaveStats.TotalAttempts)) * 100
    print(string.format("[DataProtection] System Health: %.1f%% Success Rate", rate))
end

return DataProtectionLayer
