local QBCore = exports['qb-core']:GetCoreObject()
local isPlacing = false
local canPlace = false
local currentSize = Config.DefaultSize
local currentYawOffset = 0.0
local currentRollOffset = 0.0
local previewTexture = nil
local activeGraffiti = {}

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function isValidImageUrl(url)
    if not url or url == '' then return false end
    if #Config.AllowedImageDomains == 0 then return true end

    for _, domain in ipairs(Config.AllowedImageDomains) do
        if string.find(url:lower(), domain:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function GetRotationFromNormal(normal, yawOffset, rollOffset)

    local pitch, yaw
    
    pitch = math.deg(math.asin(normal.z))
    
    yaw = math.deg(math.atan2(normal.y, normal.x))
    
    local finalPitch = 90.0 + pitch  -- THIS SHIT SUCKED
    local finalYaw = yaw + 90.0 + yawOffset  -- SAME WITH THIS LITTLE BITCH
    local finalRoll = rollOffset
    
    return vector3(finalPitch, finalRoll, finalYaw)
end

local function RotationToDirection(rotation)
    local rot = vector3(
        math.rad(rotation.x),
        math.rad(rotation.y),
        math.rad(rotation.z)
    )

    return vector3(
        -math.sin(rot.z) * math.abs(math.cos(rot.x)),
         math.cos(rot.z) * math.abs(math.cos(rot.x)),
         math.sin(rot.x)
    )
end

local function RayCastGamePlayCamera(distance)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    local direction = RotationToDirection(camRot)
    local dest = camPos + direction * distance

    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        camPos.x, camPos.y, camPos.z,
        dest.x, dest.y, dest.z,
        -1, PlayerPedId(), 0
    )

    local _, hit, coords, normal = GetShapeTestResult(ray)
    return hit, coords, normal
end

local function createGraffitiDUI(imageUrl, cb)
    local dui = CreateDui(imageUrl, 512, 512)
    if not dui then cb(nil) return end

    Wait(600)

    local handle = GetDuiHandle(dui)
    local txdName = 'graffiti_txd_' .. dui
    local txnName = 'graffiti_txn_' .. dui

    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, txnName, handle)

    cb({
        duiObj = dui,
        txdName = txdName,
        txnName = txnName
    })
end

local function cleanupPreview()
    if previewTexture and previewTexture.duiObj then
        DestroyDui(previewTexture.duiObj)
    end
    previewTexture = nil
end

local function createGraffitiTexture(graffiti, cb)
    local dui = CreateDui(graffiti.image_url, 512, 512)
    if not dui then cb(nil) return end

    Wait(600)

    local handle = GetDuiHandle(dui)
    local txdName = 'graffiti_perm_' .. graffiti.id
    local txnName = 'graffiti_tex_' .. graffiti.id

    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, txnName, handle)

    cb({
        duiObj = dui,
        txdName = txdName,
        txnName = txnName
    })
end

local function cleanupGraffitiTexture(id)
    if activeGraffiti[id] and activeGraffiti[id].texture then
        if activeGraffiti[id].texture.duiObj then
            DestroyDui(activeGraffiti[id].texture.duiObj)
        end
        activeGraffiti[id].texture = nil
    end
end

local function createGraffitiTarget(graffiti) -- 5th time is a fucking charm 
    local targetName = 'graffiti_' .. graffiti.id
    local coords = vector3(graffiti.x, graffiti.y, graffiti.z)
    
    exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.5,
        name = targetName,
        debug = Config.Debug,
        options = {
            {
                name = 'remove_graffiti_' .. graffiti.id,
                icon = 'fa-solid fa-spray-can',
                label = 'Remove Graffiti',
                items = Config.RequireScraperToRemove and Config.ScraperItem or nil,
                onSelect = function()
                    if lib.progressBar({
                        duration = 10000,
                        label = 'Removing graffiti...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true, combat = true },
                        anim = {
                            dict = 'anim@amb@drug_field_workers@rake@male_a@base',
                            clip = 'base'
                        },
                    }) then
                        TriggerServerEvent('nrx-graffiti:server:removeGraffiti', graffiti.id)
                    end
                end
            }
        }
    })
    
    return targetName
end

local function removeGraffitiTarget(id)
    local targetName = 'graffiti_' .. id
    exports.ox_target:removeZone(targetName)
end

local function startPlacementMode(imageUrl)
    if isPlacing then return end

    if not isValidImageUrl(imageUrl) then
        lib.notify({ title = 'Graffiti', description = 'Invalid image URL', type = 'error' })
        return
    end

    isPlacing = true
    canPlace = false
    currentSize = Config.DefaultSize
    currentYawOffset = 0.0
    currentRollOffset = 0.0

    createGraffitiDUI(imageUrl, function(tex)
        previewTexture = tex
    end)

    lib.notify({ 
        title = 'Graffiti', 
        description = 'Arrow Up/Down: Size | Left/Right: Rotate | Scroll: Tilt | Enter: Place | Backspace: Cancel', -- this MIGHT break, idfk
        type = 'inform',
        duration = 8000
    })

    CreateThread(function()
        while isPlacing do
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)

            DisablePlayerFiring(ped, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 38, true)

            local hit, hitCoords, surfaceNormal = RayCastGamePlayCamera(Config.PlacementRaycastDistance)

            if hit == 1 and hitCoords and surfaceNormal then
                if surfaceNormal.z > 0.7 then
                    canPlace = false
                    
                    DrawMarker( -- invalid location checker, it does not lie
                        28, 
                        hitCoords.x, hitCoords.y, hitCoords.z + 0.5,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.2, 0.2, 0.2,
                        255, 0, 0, 200,
                        false, false, 2, false,
                        nil, nil, false
                    )
                else
                    canPlace = true

                    if #(pedCoords - hitCoords) > Config.MaxPlacementDistance then
                        canPlace = false
                    end
                end

                local rotation = GetRotationFromNormal(surfaceNormal, currentYawOffset, currentRollOffset)
                local drawPos = hitCoords + (surfaceNormal * 0.02)
                local txd = previewTexture and previewTexture.txdName or nil
                local txn = previewTexture and previewTexture.txnName or nil
                local alpha = canPlace and 220 or 100
                local r = canPlace and 255 or 255
                local g = canPlace and 255 or 100
                local b = canPlace and 255 or 100

                DrawMarker(
                    9,
                    drawPos.x, drawPos.y, drawPos.z,
                    0.0, 0.0, 0.0,
                    rotation.x, rotation.y, rotation.z,
                    currentSize, currentSize, 0.001,
                    r, g, b, alpha,
                    false, false, 2, false,
                    txd, txn,
                    false
                )

                SetTextScale(0.35, 0.35)
                SetTextFont(4)
                SetTextCentre(true)
                SetTextOutline()
                SetTextColour(255, 255, 255, 255)
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(
                    string.format(
                        "Size: %.2f | Rotation: %.0f° | Tilt: %.0f° | %s",
                        currentSize,
                        currentYawOffset,
                        currentRollOffset,
                        canPlace and "~g~ENTER to place" or "~r~Cannot place here"
                    )
                )
                EndTextCommandDisplayText(0.5, 0.90)

                if IsControlJustPressed(0, 172) then -- Arrow Up
                    currentSize = math.min(currentSize + Config.SizeStep, Config.MaxSize)
                elseif IsControlJustPressed(0, 173) then -- Arrow Down
                    currentSize = math.max(currentSize - Config.SizeStep, Config.MinSize)
                end

                if IsControlPressed(0, 174) then -- Arrow Left
                    currentYawOffset = currentYawOffset - Config.RotationStep * 0.5
                elseif IsControlPressed(0, 175) then -- Arrow Right
                    currentYawOffset = currentYawOffset + Config.RotationStep * 0.5
                end

                if IsControlJustPressed(0, 14) then -- Scroll Up
                    currentRollOffset = clamp(currentRollOffset + 3.0, -45.0, 45.0)
                elseif IsControlJustPressed(0, 15) then -- Scroll Down
                    currentRollOffset = clamp(currentRollOffset - 3.0, -45.0, 45.0)
                end

                if canPlace and IsControlJustPressed(0, 191) then
                    local placementData = {
                        coords = hitCoords,
                        rotation = rotation,
                        normal = surfaceNormal,
                        size = currentSize,
                        imageUrl = imageUrl
                    }
                    
                    isPlacing = false
                    cleanupPreview()
                    
                    if lib.progressBar({
                        duration = 15000,
                        label = 'Spraying graffiti...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true, combat = true },
                        anim = {
                            dict = 'switch@franklin@lamar_tagging_wall',
                            clip = 'lamar_tagging_wall_loop_lamar'
                        },
                    }) then
                        TriggerServerEvent('nrx-graffiti:server:createGraffiti', placementData)
                    else
                        lib.notify({ title = 'Graffiti', description = 'Cancelled', type = 'inform' })
                    end
                    return
                end
            else
                canPlace = false
            end

            if IsControlJustPressed(0, 177) then
                isPlacing = false
                cleanupPreview()
                lib.notify({ title = 'Graffiti', description = 'Cancelled', type = 'inform' })
            end

            Wait(0)
        end

        cleanupPreview()
    end)
end

CreateThread(function() -- this thread was dumb af and can suck my balls from the back
    while true do
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local sleep = 500

        for id, graffiti in pairs(activeGraffiti) do
            local graffitiCoords = vector3(graffiti.x, graffiti.y, graffiti.z)
            local distance = #(playerCoords - graffitiCoords)

            if distance <= Config.RenderDistance then
                sleep = 0

                if not graffiti.texture then
                    graffiti.textureLoading = true
                    createGraffitiTexture(graffiti, function(tex)
                        graffiti.texture = tex
                        graffiti.textureLoading = false
                    end)
                end

                if graffiti.texture then
                    local rotation = vector3(graffiti.rotX, graffiti.rotY, graffiti.rotZ)
                    
                    local normal = vector3(0, 0, 0)
                    if graffiti.normal then
                        if type(graffiti.normal) == 'table' then
                            normal = vector3(graffiti.normal.x or 0, graffiti.normal.y or 0, graffiti.normal.z or 0)
                        elseif type(graffiti.normal) == 'vector3' then
                            normal = graffiti.normal
                        end
                    end
                    local drawPos = graffitiCoords + (normal * 0.02)

                    DrawMarker(
                        9,
                        drawPos.x, drawPos.y, drawPos.z,
                        0.0, 0.0, 0.0,
                        rotation.x, rotation.y, rotation.z,
                        graffiti.size, graffiti.size, 0.001,
                        255, 255, 255, 255,
                        false, false, 2, false,
                        graffiti.texture.txdName, graffiti.texture.txnName,
                        false
                    )

                end
            else
                if graffiti.texture and distance > Config.RenderDistance + 20.0 then
                    cleanupGraffitiTexture(id)
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('nrx-graffiti:client:loadGraffiti', function(graffitiList)
    for id, _ in pairs(activeGraffiti) do
        cleanupGraffitiTexture(id)
        removeGraffitiTarget(id)
    end
    activeGraffiti = {}
    
    for _, graffiti in ipairs(graffitiList) do
        activeGraffiti[graffiti.id] = graffiti
        createGraffitiTarget(graffiti)
    end
    
    if Config.Debug then
        print('[nrx-graffiti] Loaded ' .. #graffitiList .. ' graffiti')
    end
end)

RegisterNetEvent('nrx-graffiti:client:addGraffiti', function(graffiti)
    activeGraffiti[graffiti.id] = graffiti
    createGraffitiTarget(graffiti)
    
    if Config.Debug then
        print('[nrx-graffiti] Added graffiti ID:', graffiti.id)
    end
end)

RegisterNetEvent('nrx-graffiti:client:removeGraffiti', function(graffitiId)
    cleanupGraffitiTexture(graffitiId)
    removeGraffitiTarget(graffitiId)
    activeGraffiti[graffitiId] = nil
    
    if Config.Debug then
        print('[nrx-graffiti] Removed graffiti ID:', graffitiId)
    end
end)

RegisterNetEvent('nrx-graffiti:client:graffitiCreated', function(success, message)
    if success then
        lib.notify({ title = 'Graffiti', description = 'Graffiti created!', type = 'success' })
    else
        lib.notify({ title = 'Graffiti', description = message or 'Failed to create graffiti', type = 'error' })
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('nrx-graffiti:server:requestGraffiti')
end)

CreateThread(function()
    Wait(1000)
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('nrx-graffiti:server:requestGraffiti')
    end
end)

exports('spray_paint', function()
    local input = lib.inputDialog('Spray Graffiti', {
        {
            type = 'input',
            label = 'Image URL',
            placeholder = 'https://i.imgur.com/example.png',
            required = true
        }
    })

    if not input or not input[1] then return end
    startPlacementMode(input[1])
end)