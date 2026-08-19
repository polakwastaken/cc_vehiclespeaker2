Config = {}

-- Debug-Ausgaben in Konsole und Chat
Config.Debug = false

-- Debug-Kreise (Reichweite) anzeigen
Config.ShowRangeCircles = false

-- Debug-Kreis für die eigene Reichweite anzeigen
Config.ShowOwnRangeCircle = false

-- Debug-Kreise für die Reichweite anderer aktiver Lautsprecher anzeigen
Config.ShowOtherRangeCircles = false

-- PTT + Keymapping
Config.SpeakerKey = 'N'

-- Fahrzeugmodelle, in denen der Lautsprecher benutzt werden darf
Config.AllowedVehicles = {
    'nkbuffalost',
    'nkstanier',
    'nkscout',
    'polgauntlet',
    'polcoquette4',

}

-- Nur auf dem Fahrersitz nutzbar?
Config.DriverOnly = false

-- An/Aus für das ox_inventory-Item-Feature
Config.SpeakerItemEnabled = true

-- Item zum Ein-/Ausbauen in beliebigen Fahrzeugen
Config.SpeakerItem = 'vehiclespeaker'

-- ESX-Jobs, die das Item benutzen dürfen
Config.SpeakerItemJobs = {
    'police',
}

-- Ladebalken-Dauer (ox_lib) beim Ein-/Ausbauen in ms
Config.SpeakerItemDuration = 4000

-- Mindestabstand in ms zwischen zwei Ein-/Ausbau-Aktionen
Config.SpeakerItemCooldownMs = 3000

-- Item-Beschreibung während installiert, %s = Kennzeichen
Config.SpeakerItemDescriptionInstalled = 'Aktuell installiert im Fahrzeug mit dem Kennzeichen %s.'

-- Notify-Titel (cc_hud) und Texte pro Fehlerfall
Config.SpeakerItemNotifyTitle = 'Fahrzeug-Lautsprecher'
Config.SpeakerItemMessages = {
    job = 'Das Gerät ist mit einem Codeschloss gesichert - ohne passenden Dienstausweis bekommst du es nicht angeschlossen.',
    jobuninstall = 'Das Codeschloss lässt sich ohne passenden Dienstausweis nicht öffnen - du bekommst das Gerät nicht aus der Halterung.',
    novehicle = 'Du musst dazu in einem Fahrzeug sitzen.',
    notdriver = 'Du musst dazu am Steuer sitzen.',
    plate = 'Das Kennzeichen lässt sich gerade nicht auslesen.',
    builtin = 'Dieses Fahrzeug hat bereits einen fest verbauten Lautsprecher.',
    stale = 'Das hat nicht geklappt, versuch es erneut.',
    noitem = 'Du hast keinen Lautsprecher dabei.',
    occupied = 'In diesem Fahrzeug ist bereits ein anderer Lautsprecher verbaut.',
    busy = 'Du bist gerade schon dabei.',
    cooldown = 'Das ging zu schnell - warte einen Moment.',
    installed = 'Lautsprecher eingebaut.',
    relocated = 'Lautsprecher aus dem Fahrzeug %s ausgebaut und hier eingebaut.',
    uninstalled = 'Lautsprecher ausgebaut.',
}

-- Lautsprecher automatisch aus, wenn man das Fahrzeug verlässt
Config.DisableOnExitVehicle = true

-- Sprechdistanz in Metern bei aktivem Lautsprecher - gelber Kreis
Config.SpeakerRange = 35.0

-- Lautstärke-Multiplikator bei aktivem Lautsprecher
Config.SpeakerVolumeMultiplier = 5.0

-- Letzte Meter vor Config.SpeakerRange, in denen die Lautstärke weich Richtung 0 ausgeblendet wird, statt hart abzuschneiden - Orange Kreis
Config.SpeakerFadeDistance = 5.0

-- Kanal-Lautstärken für den Funkgerät-Filter (Submix)
Config.MegaphonEffect = {
    frontLeft = 1.0,   -- Vorderer linker Lautsprecher
    frontRight = 1.0, -- Vorderer rechter Lautsprecher
    rearLeft = 0.65,    -- Hinterer linker Lautsprecher
    rearRight = 0.65,   -- Hinterer rechter Lautsprecher
    channel5 = 1.0,    -- Zusätzlicher Kanal (Center/LFE je nach Routing)
    channel6 = 1.0,    -- Zusätzlicher Kanal
}
