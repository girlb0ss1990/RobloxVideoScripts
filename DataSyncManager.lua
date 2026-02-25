-- DataSyncManager.lua
-- The "Bridge" between the Data (Cloud) and the Orb (Game World)

local DataSyncManager = {}

local Players = game:GetService("Players")

-- 1. SYNC FROM DATASTORE (When player joins)
-- This runs immediately after ProfileDataManager loads the data.
function DataSyncManager.SyncAllFromDataStore(player, playerData)
    print("[DataSyncManager] Syncing game world for " .. player.Name)
    
    -- Check if they already have the orb saved in their data
    if playerData.HasOrb == true then
        -- Tell the client to hide the orb visually
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local network = ReplicatedStorage:FindFirstChild("OrbNetwork")
        
        if network and network:FindFirstChild("DataChanged") then
            network.DataChanged:FireClient(player)
            print("[DataSyncManager] Sent 'Hide Orb' signal to " .. player.Name)
        end
        
        -- Server-side safety: Make the physical orb untouchable for this player
        -- Note: In a real game, you'd handle this via a LocalScript or per-player folder
    end
end

-- 2. SYNC TO DATASTORE (When player leaves or auto-saves)
-- This is where we grab info from the game world and "pack it" into the save file.
function DataSyncManager.SyncAllToDataStore(player, playerData)
    -- In this simple tutorial, the 'HasOrb' status is usually updated 
    -- instantly when they touch it. But we can put backup logic here.
    
    playerData.LastSave = os.time()
    print("[DataSyncManager] Data packed for " .. player.Name)
end

return DataSyncManager
