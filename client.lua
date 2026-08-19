local speakerActive = false
local megaphonSubmix = nil
local activeMegaphonTargets = {}
local previousDistance = nil
local normalRange = 8.0
local toggleCooldownMs = 200

local debugColors = {
    ownSpeaker = { r = 255, g = 140, b = 0 },
    ownSpeakerFade = { r = 255, g = 230, b = 0 },
    ownNormal = { r = 0, g = 200, b = 0 },
    otherSpeaker = { r = 0, g = 160, b = 255 },
}

local allowedModelHashes = {}
for _, name in ipairs(Config.AllowedVehicles) do
    allowedModelHashes[GetHashKey(name)] = true
end

CreateThread(function()
    Wait(1000)
    TriggerEvent('pma-voice:settingsCallback', function(voiceSettings)
        for _, voiceMode in ipairs(voiceSettings.voiceModes) do
            if voiceMode[2] == 'Normal' then
                normalRange = voiceMode[1]
                break
            end
        end
    end)
end)

local function debugPrint(fmt, ...)
    if not Config.Debug then
        return
    end

    print(string.format(fmt, ...))
end

CreateThread(function()
    megaphonSubmix = CreateAudioSubmix('cc_vehiclespeaker_megaphone')

    SetAudioSubmixEffectRadioFx(megaphonSubmix, 0)
    SetAudioSubmixEffectParamInt(megaphonSubmix, 0, `default`, 1)

    SetAudioSubmixEffectParamFloat(megaphonSubmix, 0, `freq_low`, 500.0)
    SetAudioSubmixEffectParamFloat(megaphonSubmix, 0, `freq_hi`, 3000.0)

    SetAudioSubmixEffectParamFloat(megaphonSubmix, 0, `fudge`, 0.35)

    SetAudioSubmixEffectParamFloat(megaphonSubmix, 0, `rm_mix`, 0.02)
    SetAudioSubmixEffectParamFloat(megaphonSubmix, 0, `rm_mod_freq`, 0.0)

    local fx = Config.MegaphonEffect

    SetAudioSubmixOutputVolumes(
        megaphonSubmix,
        0,
        fx.frontLeft,
        fx.frontRight,
        fx.rearLeft,
        fx.rearRight,
        fx.channel5,
        fx.channel6
    )

    AddAudioSubmixOutput(megaphonSubmix, 0)

    debugPrint('Megafon Submix erstellt (ID %s).', tostring(megaphonSubmix))
end)

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

local function isSpeakerInstalled(veh)
    local installed = GlobalState.cc_vehiclespeaker_installed
    if not installed then
        return false
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    return plate ~= nil and installed[plate] == true
end

local function isInAllowedVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return false, nil
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if Config.DriverOnly and GetPedInVehicleSeat(veh, -1) ~= ped then
        return false, nil
    end

    if not allowedModelHashes[GetEntityModel(veh)] and not isSpeakerInstalled(veh) then
        return false, nil
    end

    return true, veh
end

local function resolveTargetPed(targetServerId)
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    if targetPlayer == -1 then
        return 0
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if targetPed == 0 or not DoesEntityExist(targetPed) then
        return 0
    end

    return targetPed
end

local function applySpeakerFilter(targetServerId, active)
    debugPrint('Filter %s für Server-ID %d (Submix %s, Lautstärke x%s).', active and 'AN' or 'AUS', targetServerId, tostring(megaphonSubmix), tostring(Config.SpeakerVolumeMultiplier))

    if active then
        activeMegaphonTargets[targetServerId] = true
        MumbleSetSubmixForServerId(targetServerId, megaphonSubmix)
        MumbleSetVolumeOverrideByServerId(targetServerId, Config.SpeakerVolumeMultiplier)
    else
        activeMegaphonTargets[targetServerId] = nil
        MumbleSetSubmixForServerId(targetServerId, -1)
        MumbleSetVolumeOverrideByServerId(targetServerId, -1.0)
    end
end

local function enableSpeaker()
    local proximity = LocalPlayer.state.proximity
    previousDistance = (proximity and proximity.distance) or normalRange

    speakerActive = true
    MumbleSetTalkerProximity(Config.SpeakerRange)
    Entity(PlayerPedId()).state:set('vehicleSpeaker', true, true)

    debugPrint('Speaker AN - Distanz %.1fm, vorherige Distanz %.1fm.', Config.SpeakerRange, previousDistance)
end

local function disableSpeaker()
    if not speakerActive then
        return
    end

    speakerActive = false

    local proximity = LocalPlayer.state.proximity
    local restoreDistance = (proximity and proximity.distance) or previousDistance or normalRange

    MumbleSetTalkerProximity(restoreDistance)
    Entity(PlayerPedId()).state:set('vehicleSpeaker', false, true)

    debugPrint('Speaker AUS - zurück zu Distanz %.1fm.', restoreDistance)
end

RegisterNetEvent('cc_vehiclespeaker:forceDisable', function()
    disableSpeaker()
end)

CreateThread(function()
    local knownPed = 0

    while true do
        Wait(250)

        local ped = PlayerPedId()

        if ped ~= 0 and ped ~= knownPed then
            knownPed = ped

            if speakerActive then
                disableSpeaker()
            end

            Entity(ped).state:set('vehicleSpeaker', false, true)
            debugPrint('Neuer Ped erkannt (%d) - Lautsprecher zurückgesetzt.', ped)
        end
    end
end)

local lastToggleTime = 0

RegisterKeyMapping('+cc_vehiclespeaker', 'Fahrzeug-Lautsprecher (PTT)', 'keyboard', Config.SpeakerKey)
RegisterCommand('+cc_vehiclespeaker', function()
    local now = GetGameTimer()
    if now - lastToggleTime < toggleCooldownMs then
        return
    end
    lastToggleTime = now

    local allowed, veh = isInAllowedVehicle()
    if not allowed then
        debugPrint('Taste gedrückt, aber nicht erlaubt (kein Fahrzeug / falsches Modell / falscher Sitz).')
        return
    end

    debugPrint('Taste gedrückt in Fahrzeug-Modell %d.', GetEntityModel(veh))
    enableSpeaker()
end, false)
RegisterCommand('-cc_vehiclespeaker', function()
    disableSpeaker()
end, false)

RegisterCommand('cc_vehiclespeakerstatus', function()
    local proximity = LocalPlayer.state.proximity
    debugPrint(
        'Status: aktiv=%s, eigeneServerId=%d, vorherigeDistanz=%s, pma-voice-Anzeige=%s/%s, submix=%s',
        tostring(speakerActive),
        GetPlayerServerId(PlayerId()),
        tostring(previousDistance),
        proximity and tostring(proximity.mode) or 'nil',
        proximity and tostring(proximity.distance) or 'nil',
        tostring(megaphonSubmix)
    )
end, false)

CreateThread(function()
    while true do
        local wait = 250

        if speakerActive then
            wait = 0
            SetControlNormal(0, 249, 1.0)
            SetControlNormal(1, 249, 1.0)
            SetControlNormal(2, 249, 1.0)
            MumbleSetTalkerProximity(Config.SpeakerRange)

            if Config.DisableOnExitVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
                disableSpeaker()
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        local wait = 500
        local myCoords = GetEntityCoords(PlayerPedId())

        for targetServerId in pairs(activeMegaphonTargets) do
            wait = 100

            local targetPed = resolveTargetPed(targetServerId)

            if targetPed == 0 or not Entity(targetPed).state.vehicleSpeaker then
                applySpeakerFilter(targetServerId, false)
            else
                local distance = #(myCoords - GetEntityCoords(targetPed))
                local fadeStart = Config.SpeakerRange - Config.SpeakerFadeDistance
                local volume = Config.SpeakerVolumeMultiplier

                if distance > fadeStart then
                    if Config.SpeakerFadeDistance > 0.0 then
                        local fade = 1.0 - ((distance - fadeStart) / Config.SpeakerFadeDistance)
                        volume = Config.SpeakerVolumeMultiplier * math.max(fade, 0.0)
                    else
                        volume = 0.0
                    end
                end

                MumbleSetVolumeOverrideByServerId(targetServerId, volume)
            end
        end

        Wait(wait)
    end
end)

local function drawRangeCircle(coords, radius, color)
    DrawMarker(
        1,
        coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        radius * 2.0, radius * 2.0, 1.0,
        color.r, color.g, color.b, 80,
        false, false, 2, false, nil, nil, false
    )
end

CreateThread(function()
    while true do
        local wait = 500

        if Config.ShowRangeCircles then
            if Config.ShowOwnRangeCircle then
                local ownCoords = GetEntityCoords(PlayerPedId())

                if speakerActive then
                    wait = 0
                    drawRangeCircle(ownCoords, Config.SpeakerRange, debugColors.ownSpeaker)
                    drawRangeCircle(ownCoords, Config.SpeakerRange - Config.SpeakerFadeDistance, debugColors.ownSpeakerFade)
                elseif isInAllowedVehicle() then
                    wait = 0

                    local proximity = LocalPlayer.state.proximity
                    local liveDistance = proximity and proximity.distance or normalRange

                    drawRangeCircle(ownCoords, liveDistance, debugColors.ownNormal)
                end
            end

            if Config.ShowOtherRangeCircles then
                for targetServerId in pairs(activeMegaphonTargets) do
                    local targetPed = resolveTargetPed(targetServerId)

                    if targetPed ~= 0 then
                        wait = 0
                        drawRangeCircle(GetEntityCoords(targetPed), Config.SpeakerRange, debugColors.otherSpeaker)
                    end
                end
            end
        end

        Wait(wait)
    end
end)

AddStateBagChangeHandler('vehicleSpeaker', '', function(bagName, _, value)
    local targetPed = GetEntityFromStateBagName(bagName)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
        return
    end

    if targetPed == PlayerPedId() then
        return
    end

    local targetPlayer = NetworkGetPlayerIndexFromPed(targetPed)
    if not targetPlayer or targetPlayer == -1 then
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    if targetServerId == 0 then
        return
    end

    applySpeakerFilter(targetServerId, value)
end)

CreateThread(function()
    Wait(1000)

    while true do
        local ownPed = PlayerPedId()

        for _, playerId in ipairs(GetActivePlayers()) do
            local targetPed = GetPlayerPed(playerId)

            if targetPed ~= 0 and targetPed ~= ownPed and DoesEntityExist(targetPed) then
                local targetServerId = GetPlayerServerId(playerId)
                local isSpeaking = Entity(targetPed).state.vehicleSpeaker == true

                if isSpeaking and not activeMegaphonTargets[targetServerId] then
                    applySpeakerFilter(targetServerId, true)
                elseif not isSpeaking and activeMegaphonTargets[targetServerId] then
                    applySpeakerFilter(targetServerId, false)
                end
            end
        end

        Wait(1000)
    end
end)

if Config.SpeakerItemEnabled then
    local function speakerItemNotify(messageKey, notifyType, ...)
        local message = Config.SpeakerItemMessages[messageKey] or 'Das hat nicht geklappt, versuch es erneut.'
        if select('#', ...) > 0 then
            message = message:format(...)
        end
        exports['cc_hud']:Notify('Chase City System', Config.SpeakerItemNotifyTitle, message, notifyType or 'info', 5000)
    end

    local itemBusy = false
    local lastItemUseAt = 0

    local progressLabels = {
        install = 'Lautsprecher wird eingebaut...',
        uninstall = 'Lautsprecher wird ausgebaut...',
        relocate = 'Lautsprecher wird umgebaut...',
    }

    RegisterNetEvent('cc_vehiclespeaker:useItem', function()
        if itemBusy then
            speakerItemNotify('busy', 'error')
            return
        end

        local now = GetGameTimer()
        if now - lastItemUseAt < Config.SpeakerItemCooldownMs then
            speakerItemNotify('cooldown', 'error')
            return
        end
        lastItemUseAt = now

        itemBusy = true

        local allowed, reason, plate, oldPlate = lib.callback.await('cc_vehiclespeaker:canUse', false)

        if not allowed then
            itemBusy = false
            speakerItemNotify(reason, 'error')
            return
        end

        local success = lib.progressBar({
            duration = Config.SpeakerItemDuration,
            label = progressLabels[reason] or progressLabels.install,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })

        itemBusy = false
        lastItemUseAt = GetGameTimer()

        if not success then
            TriggerServerEvent('cc_vehiclespeaker:cancelUseItem')
            return
        end

        TriggerServerEvent('cc_vehiclespeaker:commitUseItem', plate)

        if oldPlate then
            debugPrint('Lautsprecher von %s nach %s umgebaut.', oldPlate, plate)
        end
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    disableSpeaker()

    for targetServerId in pairs(activeMegaphonTargets) do
        MumbleSetSubmixForServerId(targetServerId, -1)
        MumbleSetVolumeOverrideByServerId(targetServerId, -1.0)
    end
end)
