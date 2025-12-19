local QBCore = exports['qb-core']:GetCoreObject()
local graffitiData = {}
local graffitiIdCounter = 0

local function debugPrint(...)
    if Config.Debug then -- just for testing
        print('[nrx-graffiti:server]', ...)
    end
end

local function getPlayerIdentifier(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        return Player.PlayerData.citizenid
    end
    return nil
end

local function getPlayerGraffitiCount(citizenid)
    local count = 0
    for _, graffiti in pairs(graffitiData) do
        if graffiti.creator_id == citizenid then
            count = count + 1
        end
    end
    return count
end

local function getAllGraffiti() -- pull all active for fresh loads
    local result = {}
    for _, graffiti in pairs(graffitiData) do
        result[#result + 1] = graffiti
    end
    return result
end

local function createGraffiti(data)
    graffitiIdCounter = graffitiIdCounter + 1
    local id = graffitiIdCounter
    
    local normal = data.normal
    if type(normal) == 'table' then
        normal = vector3(normal.x or 0, normal.y or 0, normal.z or 0)
    elseif type(normal) ~= 'vector3' then
        normal = vector3(0, 0, 0)
    end
    
    graffitiData[id] = {
        id = id,
        creator_id = data.creatorId,
        image_url = data.imageUrl,
        x = data.coords.x,
        y = data.coords.y,
        z = data.coords.z,
        rotX = data.rotation.x,
        rotY = data.rotation.y,
        rotZ = data.rotation.z,
        normal = {x = normal.x, y = normal.y, z = normal.z},
        size = data.size
    }
    
    return id
end

local function deleteGraffiti(id)
    if graffitiData[id] then
        graffitiData[id] = nil
        return true
    end
    return false
end

RegisterNetEvent('nrx-graffiti:server:requestGraffiti', function()
    local src = source
    local graffiti = getAllGraffiti()
    TriggerClientEvent('nrx-graffiti:client:loadGraffiti', src, graffiti)
end)

RegisterNetEvent('nrx-graffiti:server:createGraffiti', function(data)
    local src = source
    local citizenid = getPlayerIdentifier(src)
    
    if not citizenid then
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, false, 'Player not found')
        return
    end
    
    if not data or not data.coords or not data.rotation or not data.imageUrl then
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, false, 'Invalid data')
        return
    end
    
    local count = getPlayerGraffitiCount(citizenid)
    if count >= Config.MaxGraffitiPerPlayer then
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, false, 
            string.format('You have reached the maximum limit of %d graffiti', Config.MaxGraffitiPerPlayer))
        return
    end
    
    local hasItem = exports.ox_inventory:Search(src, 'count', Config.SprayPaintItem)
    
    if not hasItem or hasItem < 1 then
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, false, 'You need spray paint')
        return
    end
    
    exports.ox_inventory:RemoveItem(src, Config.SprayPaintItem, 1)
    
    local graffitiInfo = {
        creatorId = citizenid,
        imageUrl = data.imageUrl,
        coords = data.coords,
        rotation = data.rotation,
        normal = data.normal,
        size = data.size
    }
    
    local newId = createGraffiti(graffitiInfo)
    
    if newId then
        local newGraffiti = graffitiData[newId]
        
        TriggerClientEvent('nrx-graffiti:client:addGraffiti', -1, newGraffiti)
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, true)
        
        debugPrint('Created graffiti ID:', newId, 'by:', citizenid)
        debugPrint('Position:', data.coords.x, data.coords.y, data.coords.z)
        debugPrint('Rotation:', data.rotation.x, data.rotation.y, data.rotation.z)
        if data.normal then
            debugPrint('Normal:', data.normal.x, data.normal.y, data.normal.z)
        end
    else
        TriggerClientEvent('nrx-graffiti:client:graffitiCreated', src, false, 'Failed to create graffiti')
    end
end)

RegisterNetEvent('nrx-graffiti:server:removeGraffiti', function(graffitiId)
    local src = source
    local citizenid = getPlayerIdentifier(src)
    
    if not citizenid then return end
    
    if Config.RequireScraperToRemove then
        local hasItem = exports.ox_inventory:Search(src, 'count', Config.ScraperItem)
        if not hasItem or hasItem < 1 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Graffiti',
                description = 'You need a paint scraper',
                type = 'error'
            })
            return
        end
    end
    
    if not graffitiData[graffitiId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Graffiti',
            description = 'Graffiti not found',
            type = 'error'
        })
        return
    end
    
    local success = deleteGraffiti(graffitiId)
    
    if success then
        TriggerClientEvent('nrx-graffiti:client:removeGraffiti', -1, graffitiId)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Graffiti',
            description = 'Graffiti removed',
            type = 'success'
        })
        
        debugPrint('Removed graffiti ID:', graffitiId, 'by:', citizenid)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Graffiti',
            description = 'Failed to remove graffiti',
            type = 'error'
        })
    end
end)

-- Admin Commands only
QBCore.Commands.Add('clearallgraffiti', 'Clear all graffiti (Admin Only)', {}, false, function(source)
    local count = 0
    for _ in pairs(graffitiData) do count = count + 1 end
    
    graffitiData = {}
    graffitiIdCounter = 0
    
    TriggerClientEvent('nrx-graffiti:client:loadGraffiti', -1, {})
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Graffiti',
        description = string.format('Cleared %d graffiti', count),
        type = 'success'
    })
    
    debugPrint('Admin cleared all graffiti. Count:', count)
end, 'admin')

QBCore.Commands.Add('mygraffiti', 'Check your graffiti count', {}, false, function(source)
    local citizenid = getPlayerIdentifier(source)
    if citizenid then
        local count = getPlayerGraffitiCount(citizenid)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = string.format('You have %d/%d graffiti placed', count, Config.MaxGraffitiPerPlayer),
            type = 'inform'
        })
    end
end, false)

QBCore.Commands.Add('nearbygraffiti', 'List nearby graffiti IDs (Admin Only)', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    local nearby = {}
    for id, graffiti in pairs(graffitiData) do
        local dist = #(coords - vector3(graffiti.x, graffiti.y, graffiti.z))
        if dist <= 50.0 then
            nearby[#nearby + 1] = {id = id, dist = dist}
        end
    end
    
    table.sort(nearby, function(a, b) return a.dist < b.dist end)
    
    if #nearby > 0 then
        local msg = "Nearby graffiti: "
        for i, g in ipairs(nearby) do
            msg = msg .. string.format("ID %d (%.1fm)", g.id, g.dist)
            if i < #nearby then msg = msg .. ", " end
        end
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = msg,
            type = 'inform',
            duration = 10000
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = 'No graffiti within 50m',
            type = 'inform'
        })
    end
end, 'admin')

QBCore.Commands.Add('deletegraffiti', 'Delete specific graffiti by ID (Admin Only)', {{name = 'id', help = 'Graffiti ID'}}, true, function(source, args)
    local id = tonumber(args[1])
    if not id then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = 'Invalid ID',
            type = 'error'
        })
        return
    end
    
    if graffitiData[id] then
        graffitiData[id] = nil
        TriggerClientEvent('nrx-graffiti:client:removeGraffiti', -1, id)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = string.format('Deleted graffiti ID %d', id),
            type = 'success'
        })
        debugPrint('Admin deleted graffiti ID:', id)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Graffiti',
            description = 'Graffiti not found',
            type = 'error'
        })
    end
end, 'admin')

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        debugPrint('Graffiti system started (memory storage - clears on restart)')
    end
end)
