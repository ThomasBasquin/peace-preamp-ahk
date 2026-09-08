#Requires AutoHotkey v2.0

; OSD pour Peace (preamp en dB) — dual profil casque / enceintes
;
; Raccourcis:
;   F13              → baisser (step dB)
;   F14              → monter  (step dB)
;   F15              → toggle mute
;   Ctrl+Alt+F1      → profil enceintes (Peace gère le switch EQ)
;   Ctrl+Alt+F2      → profil casque    (idem)

; Réinstalle le hook clavier périodiquement (les jeux peuvent l'éjecter)
SetTimer(() => InstallKeybdHook(true, true), 5000)

; Admin requis pour écrire dans Program Files
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

peaceFile      := "C:\Program Files\EqualizerAPO\config\peace.txt"
casqueFile     := "C:\Program Files\EqualizerAPO\config\Casque.peace"
enceintesFile  := "C:\Program Files\EqualizerAPO\config\Enceintes.peace"

; ============================================================
;  CONFIGURATION DES PROFILS
; ============================================================

profiles := Map()

profiles["casque"] := {
    label     : "Casque",
    default   : -10.0,
    cur       :   0.0,
    min       : -30.0,
    max       : -10.0,
    step      :   0.5,
    warnZone  :   1.5
}

profiles["enceintes"] := {
    label     : "Enceintes",
    default   : -10.0,
    cur       :   0.0,
    min       : -30.0,
    max       :  -3.0,
    step      :   0.5,
    warnZone  :   1.5
}

activeKey := "enceintes"
profiles["casque"].cur    := profiles["casque"].default
profiles["enceintes"].cur := profiles["enceintes"].default
muted := false

; Sync le profil actif avec la valeur réelle de peace.txt au démarrage
profiles[activeKey].cur := ReadPreamp()

; ============================================================
;  LECTURE / ÉCRITURE PREAMP
; ============================================================

ReadPreamp() {
    global peaceFile
    try {
        loop read, peaceFile {
            if RegExMatch(A_LoopReadLine, "^Preamp:\s*([-\d.]+)", &m)
                return Float(m[1])
        }
    }
    return 0.0
}

WritePreamp(val) {
    global peaceFile, profiles, activeKey
    ; Filet de sécurité matériel : jamais au-dessus du plafond du profil actif
    val := Min(val, profiles[activeKey].max)
    content := ""
    loop read, peaceFile
        content .= RegExReplace(A_LoopReadLine, "^Preamp:.*", "Preamp: " Format("{:.1f}", val) " dB") "`r`n"
    f := FileOpen(peaceFile, "w")
    f.Write(content)
    f.Close()
}

; Sync périodique : vérifie que p.cur correspond à ce qu'il y a dans peace.txt
SyncPreamp() {
    global muted
    p := GetProfile()
    if (muted)   ; peace.txt est à -60, p.cur est la valeur pré-mute → pas de sync
        return
    actual := ReadPreamp()
    drift  := Abs(actual - p.cur)
    if (drift >= 0.5) {
        p.cur := actual
        ShowOSD("⚠ Sync (" p.label ")", Fmt(actual) " dB", 2500, "804000")
    }
}

SetTimer(SyncPreamp, 5000)

; ============================================================
;  OSD
; ============================================================
osdW     := 280
osdX     := (A_ScreenWidth  - osdW - 20) // 2
osdY     := A_ScreenHeight - 165
hideMs    := 2000
osdAlpha  := 242
osdHideAt := 0

osd      := ""
txtLabel := ""
txtValue := ""

CreateOSD() {
    global osd, txtLabel, txtValue, osdW, osdX, osdY
    SetTimer(OSDTick, 0)
    if IsObject(osd)
        try osd.Destroy()
    osd := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    osd.MarginX := 10
    osd.MarginY := 12
    osd.BackColor := "202020"
    osd.SetFont("s10 cAAAAAA", "Segoe UI")
    txtLabel := osd.AddText("Center w" osdW " h22", "")
    osd.SetFont("s22 cFFFFFF Bold", "Segoe UI")
    txtValue := osd.AddText("Center w" osdW, "")
    osd.Show("NoActivate x" osdX " y" osdY)
    WinSetTransparent(242, osd)
    osd.Hide()
    DllCall("dwmapi\DwmSetWindowAttribute",
        "Ptr", osd.Hwnd, "UInt", 33, "UInt*", 2, "UInt", 4)
    DllCall("dwmapi\DwmSetWindowAttribute",
        "Ptr", osd.Hwnd, "UInt", 2, "UInt*", 2, "UInt", 4)
}

CreateOSD()

ShowOSD(label, value, durationMs := 0, bgColor := "202020") {
    global osd, txtLabel, txtValue, hideMs, osdAlpha, osdHideAt, osdX, osdY
    if !IsObject(osd)
        CreateOSD()
    dur := durationMs > 0 ? durationMs : hideMs
    osd.BackColor := bgColor
    if (bgColor = "801010")
        txtLabel.SetFont("s10 cFFCCCC norm", "Segoe UI")
    else
        txtLabel.SetFont("s10 cAAAAAA norm", "Segoe UI")
    txtLabel.Text := label
    txtValue.Text := value
    osdAlpha  := 242
    osdHideAt := A_TickCount + dur
    WinSetTransparent(242, osd)
    WinSetAlwaysOnTop(1, osd)
    osd.Show("NoActivate x" osdX " y" osdY)
    SetTimer(OSDTick, 25)
}

OSDTick() {
    global osd, osdAlpha, osdHideAt
    if (A_TickCount < osdHideAt)
        return
    osdAlpha -= 27
    if (osdAlpha <= 0) {
        SetTimer(OSDTick, 0)
        osd.Hide()
        osdAlpha := 242
        WinSetTransparent(242, osd)
        return
    }
    WinSetTransparent(osdAlpha, osd)
}

; ============================================================
;  DEVICES AUDIO — anti-dérive GUID (DAC USB qui change d'identité)
; ============================================================
; Chaque profil .peace est verrouillé sur un "Device GUID" Windows figé.
; Un DAC USB peut se voir attribuer un nouveau GUID par
; Windows à chaque reconnexion/veille, ce qui rend le profil incapable de
; retrouver le périphérique → le switch ne fait plus rien, silencieusement.
; On revérifie donc le GUID juste avant chaque switch et on le corrige au vol.

MMRenderKey := "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
PKEY_JackName    := "{a45c254e-df1c-4efd-8020-67d146a850e0},2"
PKEY_ProductName := "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"

; Lit "Device=<jack>, <produit>" dans le fichier .peace
ReadDeviceRef(peaceProfileFile) {
    loop read, peaceProfileFile {
        if RegExMatch(A_LoopReadLine, "^Device=([^,]+),\s*(.+)$", &m)
            return { jack: Trim(m[1]), product: Trim(m[2]) }
    }
    return ""
}

; Cherche parmi les endpoints AUDIO ACTIFS celui dont jack+produit correspondent
FindActiveDeviceGuid(jack, product) {
    global MMRenderKey, PKEY_JackName, PKEY_ProductName
    loop reg, MMRenderKey, "K" {
        guidKey := A_LoopRegName
        try state := RegRead(MMRenderKey "\" guidKey, "DeviceState")
        catch
            continue
        if ((state & 0xF) != 1)   ; pas "Active"
            continue
        try {
            j := RegRead(MMRenderKey "\" guidKey "\Properties", PKEY_JackName)
            p := RegRead(MMRenderKey "\" guidKey "\Properties", PKEY_ProductName)
        } catch
            continue
        if (j = jack && p = product)
            return guidKey
    }
    return ""
}

; Vérifie que le périphérique du profil est bien branché/actif.
; Si oui : corrige le "Device GUID=" dans le fichier s'il a dérivé, renvoie true.
; Si non (éteint/débranché) : renvoie false sans toucher au fichier.
EnsureDeviceReady(peaceProfileFile) {
    ref := ReadDeviceRef(peaceProfileFile)
    if !IsObject(ref)
        return true  ; pas de ligne Device= trouvée, on ne bloque pas

    activeGuid := FindActiveDeviceGuid(ref.jack, ref.product)
    if (activeGuid = "")
        return false

    content := ""
    changed := false
    loop read, peaceProfileFile {
        line := A_LoopReadLine
        if RegExMatch(line, "^Device GUID=\{[0-9a-fA-F-]+\}") {
            newLine := "Device GUID=" activeGuid
            if (line != newLine)
                changed := true
            line := newLine
        }
        content .= line "`r`n"
    }
    if changed {
        f := FileOpen(peaceProfileFile, "w")
        f.Write(content)
        f.Close()
    }
    return true
}

; ============================================================
;  UTILITAIRES
; ============================================================
GetProfile() {
    global profiles, activeKey
    return profiles[activeKey]
}

Fmt(val) {
    return Format("{:.1f}", val)
}

; ============================================================
;  HOTKEYS
; ============================================================

; --- Volume bas ---
$F13:: {
    global muted
    p := GetProfile()

    newVal := p.cur - p.step
    if (newVal < p.min) {
        p.cur := p.min
        muted := false
        WritePreamp(p.cur)
        ShowOSD(p.label, Fmt(p.cur) " dB  [MIN]")
        return
    }

    p.cur  := newVal
    muted  := false
    WritePreamp(p.cur)

    if (p.cur > p.max)
        ShowOSD("Plafond dépassé (" Fmt(p.max) " dB)", "⚠   " Fmt(p.cur) " dB", 0, "801010")
    else if (p.cur >= p.max - p.warnZone)
        ShowOSD(p.label, "⚠   " Fmt(p.cur) " dB")
    else
        ShowOSD(p.label, Fmt(p.cur) " dB")
}

; --- Volume haut ---
$F14:: {
    global muted
    p := GetProfile()

    newVal := p.cur + p.step
    if (newVal > p.max) {
        p.cur := p.max
        muted := false
        WritePreamp(p.cur)
        ShowOSD("Plafond (" Fmt(p.max) " dB)", "⚠   " Fmt(p.cur) " dB", 0, "801010")
        return
    }

    p.cur  := newVal
    muted  := false
    WritePreamp(p.cur)

    if (p.cur >= p.max - p.warnZone)
        ShowOSD(p.label, "⚠   " Fmt(p.cur) " dB")
    else
        ShowOSD(p.label, Fmt(p.cur) " dB")
}

; --- Mute toggle ---
$F15:: {
    global muted
    p := GetProfile()
    muted := !muted
    if (muted)
        WritePreamp(-60.0)
    else
        WritePreamp(p.cur)
    ShowOSD(p.label, muted ? "🔇" : Fmt(p.cur) " dB")
}

; --- Profil enceintes ---
$^!F1:: {
    global activeKey, muted, osdX, osdY, osdW, enceintesFile
    if !EnsureDeviceReady(enceintesFile) {
        ShowOSD("Profil", "Enceintes ⚠", 2500, "801010")
        return
    }
    activeKey := "enceintes"
    muted := false
    Send("^!{F1}")
    p := GetProfile()
    p.cur := p.default
    osdX := (A_ScreenWidth - osdW - 20) // 2
    osdY := A_ScreenHeight - 165
    ShowOSD("Profil", p.label " (" Fmt(p.cur) " dB)", 2500)
}

; --- Profil casque ---
$^!F2:: {
    global activeKey, muted, osdX, osdY, osdW, casqueFile
    if !EnsureDeviceReady(casqueFile) {
        ShowOSD("Profil", "Casque ⚠", 2500, "801010")
        return
    }
    activeKey := "casque"
    muted := false
    Send("^!{F2}")
    p := GetProfile()
    p.cur := p.default
    osdX := (A_ScreenWidth - osdW - 20) // 2
    osdY := A_ScreenHeight - 165
    ShowOSD("Profil", p.label " (" Fmt(p.cur) " dB)", 2500)
}
