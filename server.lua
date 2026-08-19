local function normalizePlate(plate)
    if type(plate) ~= 'string' then
        return nil
    end

    local normalized = string.upper((plate:gsub('^%s*(.-)%s*$', '%1')))
    if normalized == '' then
        return nil
    end

    return normalized
end

local validateIntervalMs = 3000
local resyncIntervalMs = 30000
local cleanupIntervalMs = 30000

local allowedModelHashes = {}
for _, name in ipairs(Config.AllowedVehicles) do
    allowedModelHashes[GetHashKey(name)] = true
end

local InstalledSpeakers = {}

GlobalState.cc_vehiclespeaker_installed = {}

local function isVehicleSpeakerAllowed(veh)
    if allowedModelHashes[GetEntityModel(veh)] then
        return true
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    return plate ~= nil and InstalledSpeakers[plate] ~= nil
end

local activeSpeakers = {}

local function findPlayerByPed(ped)
    local owner = NetworkGetEntityOwner(ped)

    if owner then
        local playerId = tostring(owner)
        if GetPlayerPed(playerId) == ped then
            return playerId
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        if GetPlayerPed(playerId) == ped then
            return playerId
        end
    end

    return nil
end

AddStateBagChangeHandler('vehicleSpeaker', '', function(bagName, _, value)
    local ped = GetEntityFromStateBagName(bagName)
    if not ped or ped == 0 then
        return
    end

    local playerId = findPlayerByPed(ped)
    if not playerId then
        return
    end

    activeSpeakers[playerId] = value == true or nil
end)

local function validateSpeaker(playerId)
    local ped = GetPlayerPed(playerId)

    if ped == 0 or not Entity(ped).state.vehicleSpeaker then
        activeSpeakers[playerId] = nil
        return
    end

    if IsPedInAnyVehicle(ped, false) and isVehicleSpeakerAllowed(GetVehiclePedIsIn(ped, false)) then
        return
    end

    Entity(ped).state:set('vehicleSpeaker', false, true)
    TriggerClientEvent('cc_vehiclespeaker:forceDisable', playerId)
    activeSpeakers[playerId] = nil
end

CreateThread(function()
    while true do
        Wait(validateIntervalMs)

        for playerId in pairs(activeSpeakers) do
            validateSpeaker(playerId)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(resyncIntervalMs)

        for _, playerId in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(playerId)

            if ped ~= 0 and Entity(ped).state.vehicleSpeaker then
                activeSpeakers[playerId] = true
                validateSpeaker(playerId)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    activeSpeakers[tostring(source)] = nil
end)

if not Config.SpeakerItemEnabled then
    return
end

local ESX = exports['es_extended']:getSharedObject()

local allowedJobs = {}
for _, jobName in ipairs(Config.SpeakerItemJobs) do
    allowedJobs[jobName] = true
end

local lastActionAt = {}
local pendingUntil = {}

local function syncInstalled()
    local plates = {}
    for plate in pairs(InstalledSpeakers) do
        plates[plate] = true
    end

    GlobalState.cc_vehiclespeaker_installed = plates
end

local function notify(source, messageKey, notifyType, ...)
    local message = Config.SpeakerItemMessages[messageKey] or Config.SpeakerItemMessages.stale
    if select('#', ...) > 0 then
        message = message:format(...)
    end

    exports['cc_hud']:NotifyClient(source, 'Chase City System', Config.SpeakerItemNotifyTitle, message, notifyType or 'info', 5000)
end

local function getSlotPlate(slot)
    if type(slot) ~= 'table' or type(slot.metadata) ~= 'table' then
        return nil
    end

    return normalizePlate(slot.metadata.plate)
end

local function findSpeakerSlot(source, plate)
    local slots = exports.ox_inventory:Search(source, 'slots', Config.SpeakerItem)
    if type(slots) ~= 'table' or not slots[1] then
        return nil
    end

    local fallback = nil

    for i = 1, #slots do
        local slot = slots[i]
        local slotPlate = getSlotPlate(slot)

        if slotPlate == plate then
            return slot
        end

        if not fallback and not slotPlate then
            fallback = slot
        end
    end

    return fallback or slots[1]
end

local function writeSlotPlate(source, slot, plate)
    if type(slot) ~= 'table' or not slot.slot then
        return
    end

    local metadata = {}

    if type(slot.metadata) == 'table' then
        for key, value in pairs(slot.metadata) do
            metadata[key] = value
        end
    end

    if plate then
        metadata.plate = plate
        metadata.description = Config.SpeakerItemDescriptionInstalled:format(plate)
    else
        metadata.plate = nil
        metadata.description = nil
    end

    exports.ox_inventory:SetMetadata(source, slot.slot, metadata)
end

local function clearSlotPlateForOwner(owner, plate)
    if not owner then
        return
    end

    local xPlayer = ESX.GetPlayerFromIdentifier(owner)
    if not xPlayer then
        return
    end

    local slots = exports.ox_inventory:Search(xPlayer.source, 'slots', Config.SpeakerItem)
    if type(slots) ~= 'table' then
        return
    end

    for i = 1, #slots do
        if getSlotPlate(slots[i]) == plate then
            writeSlotPlate(xPlayer.source, slots[i], nil)
        end
    end
end

local function checkUsage(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false, 'job'
    end

    local ped = GetPlayerPed(source)
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then
        return false, 'novehicle'
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return false, 'notdriver'
    end

    if allowedModelHashes[GetEntityModel(veh)] then
        return false, 'builtin'
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    if not plate then
        return false, 'plate'
    end

    local slot = findSpeakerSlot(source, plate)
    if not slot then
        return false, 'noitem'
    end

    local slotPlate = getSlotPlate(slot)
    local installedHere = InstalledSpeakers[plate] ~= nil
    local isUninstall = installedHere and slotPlate == plate

    if not allowedJobs[xPlayer.job.name] then
        return false, isUninstall and 'jobuninstall' or 'job'
    end

    if installedHere then
        if isUninstall then
            return true, 'uninstall', plate, slot
        end

        return false, 'occupied'
    end

    if slotPlate and slotPlate ~= plate and InstalledSpeakers[slotPlate] then
        return true, 'relocate', plate, slot, slotPlate
    end

    return true, 'install', plate, slot
end

lib.callback.register('cc_vehiclespeaker:canUse', function(source)
    local now = GetGameTimer()

    if pendingUntil[source] and now < pendingUntil[source] then
        return false, 'busy'
    end

    if lastActionAt[source] and now - lastActionAt[source] < Config.SpeakerItemCooldownMs then
        return false, 'cooldown'
    end

    local allowed, reason, plate, _, oldPlate = checkUsage(source)

    if not allowed then
        return false, reason
    end

    pendingUntil[source] = now + Config.SpeakerItemDuration + 5000

    return true, reason, plate, oldPlate
end)

RegisterNetEvent('cc_vehiclespeaker:cancelUseItem', function()
    pendingUntil[source] = nil
end)

RegisterNetEvent('cc_vehiclespeaker:commitUseItem', function(plate)
    local source = source

    if type(plate) ~= 'string' then
        return
    end

    pendingUntil[source] = nil

    local now = GetGameTimer()
    if lastActionAt[source] and now - lastActionAt[source] < Config.SpeakerItemCooldownMs then
        notify(source, 'cooldown', 'error')
        return
    end

    local allowed, action, currentPlate, slot, oldPlate = checkUsage(source)

    if not allowed then
        notify(source, action, 'error')
        return
    end

    if currentPlate ~= plate then
        notify(source, 'stale', 'error')
        return
    end

    lastActionAt[source] = now

    if action == 'uninstall' then
        InstalledSpeakers[plate] = nil
        writeSlotPlate(source, slot, nil)
        syncInstalled()
        notify(source, 'uninstalled', 'success')
        return
    end

    if action == 'relocate' then
        InstalledSpeakers[oldPlate] = nil
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    InstalledSpeakers[plate] = { owner = xPlayer and xPlayer.identifier or nil }
    writeSlotPlate(source, slot, plate)
    syncInstalled()

    if action == 'relocate' then
        notify(source, 'relocated', 'success', oldPlate)
    else
        notify(source, 'installed', 'success')
    end
end)

CreateThread(function()
    while true do
        Wait(cleanupIntervalMs)

        if next(InstalledSpeakers) then
            local existingPlates = {}
            local vehicles = GetAllVehicles()

            for i = 1, #vehicles do
                local plate = normalizePlate(GetVehicleNumberPlateText(vehicles[i]))
                if plate then
                    existingPlates[plate] = true
                end
            end

            local changed = false

            for plate, data in pairs(InstalledSpeakers) do
                if not existingPlates[plate] then
                    InstalledSpeakers[plate] = nil
                    changed = true
                    clearSlotPlateForOwner(data.owner, plate)
                end
            end

            if changed then
                syncInstalled()
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastActionAt[source] = nil
    pendingUntil[source] = nil
end)
