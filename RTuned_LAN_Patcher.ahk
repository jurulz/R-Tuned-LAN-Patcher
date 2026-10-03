#Requires AutoHotkey v2.0
#SingleInstance Force

; R-Tuned LAN Patcher v2.2b - V2.1 Extended
; Mode 2 uses the exact proven V2.1 TX machine-code layout.
; Modes 3/4 extend that same explicit-addressing approach and are NOT TESTED.
; RX remains exactly the validated V2.1 6-byte patch.

EXPECTED_SHA := "540335426caa63663314fa826adeaee13fcf78b4b068238c3275cdef23c1ead1"
PATCH_OFFSET := 0x13ED29
PATCH_REGION_LEN := 0x7D
RX_JNE_OFFSET := 0x13F141
RX_JNE_ORIGINAL := "0F851BFFFFFF"
RX_JMP_PATCH := "E92FFFFFFF90"

global TargetFile := ""
global PrivateIPs := DetectPrivateIPv4()
global Lang := "EN"

Main := Gui("+Resize", "R-Tuned LAN Patcher v2.2b")
Main.SetFont("s10", "Segoe UI")
TitleTxt := Main.AddText("xm w700", "R-Tuned LAN Patcher v2.2b — V2.1 Extended")
Main.SetFont("s9", "Segoe UI")
LangTxt := Main.AddText("xm y+10", "Language / Langue:")
LangDDL := Main.AddDropDownList("x+8 yp-3 w150 Choose1", ["English", "Français"])

FileLbl := Main.AddText("xm y+18", "Original dsr_HD:")
PathEdit := Main.AddEdit("xm y+4 w570 ReadOnly")
BrowseBtn := Main.AddButton("x+8 yp-1 w110", "Browse...")

DetectedLbl := Main.AddText("xm y+18", "Private IPv4 detected on this PC:")
DetectedDDL := Main.AddDropDownList("xm y+4 w300", PrivateIPs.Length ? PrivateIPs : ["None detected"])
RefreshBtn := Main.AddButton("x+8 yp-1 w110", "Refresh")

CountGroup := Main.AddGroupBox("xm y+20 w700 h90", "Cabinet configuration")
Count2 := Main.AddRadio("xm+20 yp+30 Checked", "2 Cabinets   ✓ TESTED")
Count3 := Main.AddRadio("x+35 yp", "3 Cabinets   ⚠ NOT TESTED")
Count4 := Main.AddRadio("x+35 yp", "4 Cabinets   ⚠ NOT TESTED")
CountNote := Main.AddText("xm+20 y+14 w650", "2-cabinet mode reproduces the proven V2.1 TX patch. 3/4 modes are experimental.")

DestGroup := Main.AddGroupBox("xm y+18 w700 h220", "Real LAN destinations")
Cab1Lbl := Main.AddText("xm+20 yp+32 w100", "CAB1 IP:")
Cab1Edit := Main.AddEdit("x+5 yp-3 w180")
UseLocal1 := Main.AddButton("x+8 yp-1 w120", "Use local")
Cab2Lbl := Main.AddText("xm+20 y+18 w100", "CAB2 IP:")
Cab2Edit := Main.AddEdit("x+5 yp-3 w180")
UseLocal2 := Main.AddButton("x+8 yp-1 w120", "Use local")
Cab3Lbl := Main.AddText("xm+20 y+18 w100", "CAB3 IP:")
Cab3Edit := Main.AddEdit("x+5 yp-3 w180")
UseLocal3 := Main.AddButton("x+8 yp-1 w120", "Use local")
Cab4Lbl := Main.AddText("xm+20 y+18 w100", "CAB4 IP:")
Cab4Edit := Main.AddEdit("x+5 yp-3 w180")
UseLocal4 := Main.AddButton("x+8 yp-1 w120", "Use local")
DupNote := Main.AddText("xm+20 y+18 w650", "Duplicate IPs are allowed for lab testing. Use unique IPs for real 3/4-cabinet installations.")

PatchBtn := Main.AddButton("xm y+22 w160 h34 Default", "Create patched ELF")
RestoreBtn := Main.AddButton("x+10 yp w160 h34", "Restore backup")
VerifyBtn := Main.AddButton("x+10 yp w160 h34", "Verify")
OpenFolderBtn := Main.AddButton("x+10 yp w160 h34", "Open folder")
Status := Main.AddEdit("xm y+18 w700 h140 ReadOnly -Wrap", "Ready.`r`nSelect the original dsr_HD.")

BrowseBtn.OnEvent("Click", BrowseFile)
RefreshBtn.OnEvent("Click", RefreshIPs)
UseLocal1.OnEvent("Click", (*) => SetFromDetected(Cab1Edit))
UseLocal2.OnEvent("Click", (*) => SetFromDetected(Cab2Edit))
UseLocal3.OnEvent("Click", (*) => SetFromDetected(Cab3Edit))
UseLocal4.OnEvent("Click", (*) => SetFromDetected(Cab4Edit))
PatchBtn.OnEvent("Click", PatchFile)
RestoreBtn.OnEvent("Click", RestoreBackup)
VerifyBtn.OnEvent("Click", VerifyTarget)
OpenFolderBtn.OnEvent("Click", OpenTargetFolder)
LangDDL.OnEvent("Change", ChangeLanguage)
Count2.OnEvent("Click", UpdateCabFields)
Count3.OnEvent("Click", UpdateCabFields)
Count4.OnEvent("Click", UpdateCabFields)
Main.OnEvent("Close", (*) => ExitApp())
RefreshIPs()
UpdateCabFields()
Main.Show("w740 h720")

GetCount() {
    global Count2, Count3, Count4
    return Count2.Value ? 2 : (Count3.Value ? 3 : 4)
}

ChangeLanguage(*) {
    global Lang, LangDDL, FileLbl, BrowseBtn, DetectedLbl, RefreshBtn, CountGroup, Count2, Count3, Count4, CountNote
    global DestGroup, Cab1Lbl, Cab2Lbl, Cab3Lbl, Cab4Lbl, UseLocal1, UseLocal2, UseLocal3, UseLocal4, DupNote
    global PatchBtn, RestoreBtn, VerifyBtn, OpenFolderBtn, Status
    Lang := (LangDDL.Value = 2) ? "FR" : "EN"
    if (Lang = "FR") {
        FileLbl.Text := "dsr_HD original :", BrowseBtn.Text := "Parcourir...", DetectedLbl.Text := "IPv4 privées détectées sur ce PC :", RefreshBtn.Text := "Actualiser"
        CountGroup.Text := "Configuration des cabinets", Count2.Text := "2 Cabinets   ✓ TESTÉ", Count3.Text := "3 Cabinets   ⚠ NON TESTÉ", Count4.Text := "4 Cabinets   ⚠ NON TESTÉ"
        CountNote.Text := "Le mode 2 cabinets reproduit le patch TX V2.1 éprouvé. Les modes 3/4 sont expérimentaux."
        DestGroup.Text := "Destinations LAN réelles", Cab1Lbl.Text := "IP CAB1 :", Cab2Lbl.Text := "IP CAB2 :", Cab3Lbl.Text := "IP CAB3 :", Cab4Lbl.Text := "IP CAB4 :"
        UseLocal1.Text := "Utiliser locale", UseLocal2.Text := "Utiliser locale", UseLocal3.Text := "Utiliser locale", UseLocal4.Text := "Utiliser locale"
        DupNote.Text := "Les IP dupliquées sont permises pour les tests labo. Utilisez des IP uniques pour une vraie installation 3/4 cabinets."
        PatchBtn.Text := "Créer ELF patché", RestoreBtn.Text := "Restaurer backup", VerifyBtn.Text := "Vérifier", OpenFolderBtn.Text := "Ouvrir dossier"
        Status.Value := "Prêt.`r`nSélectionnez le dsr_HD original."
    } else {
        FileLbl.Text := "Original dsr_HD:", BrowseBtn.Text := "Browse...", DetectedLbl.Text := "Private IPv4 detected on this PC:", RefreshBtn.Text := "Refresh"
        CountGroup.Text := "Cabinet configuration", Count2.Text := "2 Cabinets   ✓ TESTED", Count3.Text := "3 Cabinets   ⚠ NOT TESTED", Count4.Text := "4 Cabinets   ⚠ NOT TESTED"
        CountNote.Text := "2-cabinet mode reproduces the proven V2.1 TX patch. 3/4 modes are experimental."
        DestGroup.Text := "Real LAN destinations", Cab1Lbl.Text := "CAB1 IP:", Cab2Lbl.Text := "CAB2 IP:", Cab3Lbl.Text := "CAB3 IP:", Cab4Lbl.Text := "CAB4 IP:"
        UseLocal1.Text := "Use local", UseLocal2.Text := "Use local", UseLocal3.Text := "Use local", UseLocal4.Text := "Use local"
        DupNote.Text := "Duplicate IPs are allowed for lab testing. Use unique IPs for real 3/4-cabinet installations."
        PatchBtn.Text := "Create patched ELF", RestoreBtn.Text := "Restore backup", VerifyBtn.Text := "Verify", OpenFolderBtn.Text := "Open folder"
        Status.Value := "Ready.`r`nSelect the original dsr_HD."
    }
}

UpdateCabFields(*) {
    global Cab3Edit, Cab4Edit, UseLocal3, UseLocal4
    n := GetCount()
    Cab3Edit.Enabled := n >= 3, UseLocal3.Enabled := n >= 3
    Cab4Edit.Enabled := n >= 4, UseLocal4.Enabled := n >= 4
}

BrowseFile(*) {
    global TargetFile, PathEdit, Lang
    f := FileSelect(1, , Lang="FR" ? "Sélectionner dsr_HD" : "Select dsr_HD", "All files (*.*)")
    if !f
        return
    TargetFile := f, PathEdit.Value := f
    VerifyTarget()
}

RefreshIPs(*) {
    global PrivateIPs, DetectedDDL, Cab1Edit, Cab2Edit
    PrivateIPs := DetectPrivateIPv4(), DetectedDDL.Delete()
    if PrivateIPs.Length {
        DetectedDDL.Add(PrivateIPs), DetectedDDL.Choose(1)
        if Cab1Edit.Value = ""
            Cab1Edit.Value := DetectedDDL.Text
        if Cab2Edit.Value = ""
            Cab2Edit.Value := SuggestAdjacentIP(DetectedDDL.Text)
    } else {
        DetectedDDL.Add(["None detected"]), DetectedDDL.Choose(1)
    }
}

SetFromDetected(ctrl) {
    global DetectedDDL
    if IsIPv4(DetectedDDL.Text)
        ctrl.Value := DetectedDDL.Text
}

PatchFile(*) {
    global TargetFile, Cab1Edit, Cab2Edit, Cab3Edit, Cab4Edit, PATCH_OFFSET, PATCH_REGION_LEN
    global RX_JNE_OFFSET, RX_JNE_ORIGINAL, RX_JMP_PATCH, Status, Lang
    if !FileExist(TargetFile) {
        MsgBox(Lang="FR" ? "Sélectionnez d'abord dsr_HD." : "Select dsr_HD first.", "R-Tuned Patcher", "Icon!")
        return
    }
    n := GetCount()
    ips := [Trim(Cab1Edit.Value), Trim(Cab2Edit.Value), Trim(Cab3Edit.Value), Trim(Cab4Edit.Value)]
    Loop n {
        if !IsPrivateIPv4(ips[A_Index]) {
            MsgBox((Lang="FR" ? "CAB" A_Index " doit contenir une IPv4 privée valide." : "CAB" A_Index " must contain a valid private IPv4 address."), "R-Tuned Patcher", "Icon!")
            return
        }
    }
    originalPrefix := "8B550883C201837DEC007E770FB77DF2BB8CE85108"
    if StrUpper(ReadHex(TargetFile, PATCH_OFFSET, StrLen(originalPrefix)//2)) != originalPrefix {
        MsgBox(Lang="FR" ? "Signature TX originale incorrecte. Utilisez le dsr_HD original." : "Original TX signature mismatch. Use the original dsr_HD.", "R-Tuned Patcher", "Iconx")
        return
    }
    if StrUpper(ReadHex(TargetFile, RX_JNE_OFFSET, 6)) != RX_JNE_ORIGINAL {
        MsgBox(Lang="FR" ? "Signature RX originale incorrecte. Patch annulé." : "Original RX signature mismatch. Patch cancelled.", "R-Tuned Patcher", "Iconx")
        return
    }
    backup := TargetFile ".rtuned-original.bak"
    if !FileExist(backup)
        FileCopy(TargetFile, backup, 0)

    ; Common V2.1 sockaddr initialization prefix. Count is the selected N.
    patchHex := "C70588E85108" . Format("{:02X}000000", n) .
        "BB8CE85108" . "31C9" . "C70300000000" . "C7430400000000" . "C7430800000000" . "C7430C00000000" .
        "66C7030200" . "668B45F2" . "66C1C808" . "66894302"

    if (n = 2) {
        ; EXACT V2.1 TX selection logic and layout.
        patchHex .= "85C9" . "7507" . "B8" . IPv4ToHex(ips[1]) . "EB05" . "B8" . IPv4ToHex(ips[2]) .
                    "894304" . "83C310" . "41" . "83F902" . "7CB8"
    } else if (n = 3) {
        ; V2.1-style explicit selector extended to CAB3. NOT TESTED.
        patchHex .= "83F900" . "740C" . "83F901" . "740E" . "B8" . IPv4ToHex(ips[3]) . "EB0C" .
                    "B8" . IPv4ToHex(ips[1]) . "EB05" . "B8" . IPv4ToHex(ips[2]) .
                    "894304" . "83C310" . "41" . "83F903" . "7CAB"
    } else {
        ; V2.1-style explicit selector extended to CAB4. NOT TESTED.
        patchHex .= "83F900" . "7411" . "83F901" . "7413" . "83F902" . "7415" . "B8" . IPv4ToHex(ips[4]) . "EB13" .
                    "B8" . IPv4ToHex(ips[1]) . "EB0C" . "B8" . IPv4ToHex(ips[2]) . "EB05" . "B8" . IPv4ToHex(ips[3]) .
                    "894304" . "83C310" . "41" . "83F904" . "7C9F"
    }

    patchBytes := StrLen(patchHex)//2
    if patchBytes > PATCH_REGION_LEN {
        MsgBox("Internal error: TX patch is too large (" patchBytes " bytes).", "R-Tuned Patcher", "Iconx")
        return
    }
    Loop PATCH_REGION_LEN-patchBytes
        patchHex .= "90"

    out := TargetFile ".LANPATCHED_V22b_" n "CAB"
    FileCopy(TargetFile, out, 1)
    WriteHex(out, PATCH_OFFSET, patchHex)
    WriteHex(out, RX_JNE_OFFSET, RX_JMP_PATCH)
    if StrUpper(ReadHex(out, RX_JNE_OFFSET, 6)) != RX_JMP_PATCH {
        try FileDelete(out)
        MsgBox("RX validation failed.", "R-Tuned Patcher", "Iconx")
        return
    }
    modeStatus := n=2 ? (Lang="FR" ? "TESTÉ — logique TX V2.1" : "TESTED — V2.1 TX logic") : (Lang="FR" ? "NON TESTÉ" : "NOT TESTED")
    Status.Value := (Lang="FR" ? "PATCH CRÉÉ AVEC SUCCÈS" : "PATCH CREATED SUCCESSFULLY") . "`r`n`r`n" .
        "Mode: " n " CAB — " modeStatus "`r`n" . "RX: V2.1 unchanged / inchangé`r`n" . "Output: " out "`r`nBackup: " backup
    MsgBox((Lang="FR" ? "ELF créé :" : "ELF created:") "`n`n" out "`n`n" modeStatus, "R-Tuned Patcher", "Iconi")
}

RestoreBackup(*) {
    global TargetFile, Status, Lang
    if TargetFile=""
        return
    backup := TargetFile ".rtuned-original.bak"
    if !FileExist(backup) {
        MsgBox(Lang="FR" ? "Aucun backup trouvé." : "No backup found.", "R-Tuned Patcher", "Icon!")
        return
    }
    FileCopy(backup, TargetFile, 1)
    Status.Value := Lang="FR" ? "Original restauré." : "Original restored."
}

VerifyTarget(*) {
    global TargetFile, Status, Lang, EXPECTED_SHA
    if !FileExist(TargetFile) {
        Status.Value := Lang="FR" ? "Aucun fichier sélectionné." : "No file selected."
        return
    }
    h := GetSHA256(TargetFile)
    Status.Value := "SHA-256: " h "`r`n" . (h=EXPECTED_SHA ? "Known original / Original connu" : "SHA differs; opcode signatures will still be checked / SHA différent; signatures vérifiées")
}

OpenTargetFolder(*) {
    global TargetFile
    if TargetFile=""
        return
    SplitPath(TargetFile, , &dir)
    Run('explorer.exe "' dir '"')
}

; ---------------- Helpers ----------------

DetectPrivateIPv4() {
    ps :=
    (
    "$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | " .
    "Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | " .
    "ForEach-Object { $_.IPAddress } | Sort-Object -Unique; " .
    "$ips"
    )
    txt := RunPSCapture(ps)
    arr := []
    for line in StrSplit(txt, "`n", "`r") {
        ip := Trim(line)
        if IsPrivateIPv4(ip)
            arr.Push(ip)
    }
    return arr
}

RunPSCapture(command) {
    tmp := A_Temp "\rtuned_" A_TickCount ".txt"
    cmd := 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "' .
           StrReplace(command, '"', '\"') . '"'
    RunWait(A_ComSpec ' /c ' cmd ' > "' tmp '"', , "Hide")
    txt := FileExist(tmp) ? FileRead(tmp) : ""
    try FileDelete(tmp)
    return txt
}

GetSHA256(path) {
    ps := "(Get-FileHash -Algorithm SHA256 -LiteralPath '" StrReplace(path, "'", "''") "').Hash"
    return StrLower(Trim(RunPSCapture(ps)))
}

IsIPv4(ip) {
    parts := StrSplit(ip, ".")
    if (parts.Length != 4)
        return false
    for p in parts {
        if !RegExMatch(p, "^\d{1,3}$")
            return false
        n := Integer(p)
        if (n < 0 || n > 255)
            return false
    }
    return true
}

IsPrivateIPv4(ip) {
    if !IsIPv4(ip)
        return false
    p := StrSplit(ip, ".")
    a := Integer(p[1]), b := Integer(p[2])
    return (a = 10) || (a = 192 && b = 168) || (a = 172 && b >= 16 && b <= 31)
}

SuggestAdjacentIP(ip) {
    p := StrSplit(ip, ".")
    last := Integer(p[4])
    if (last < 254)
        last += 1
    else
        last -= 1
    return p[1] "." p[2] "." p[3] "." last
}

IPv4ToHex(ip) {
    ; L'immédiat x86 est écrit little-endian dans l'instruction.
    ; En utilisant les octets réseau directement (C0 A8 ...), EAX stocké
    ; en mémoire produit exactement sin_addr en network byte order.
    p := StrSplit(ip, ".")
    out := ""
    for n in p
        out .= Format("{:02X}", Integer(n))
    return out
}

ReadHex(path, offset, count) {
    f := FileOpen(path, "r")
    if !IsObject(f)
        return ""
    f.Pos := offset
    buf := Buffer(count, 0)
    got := f.RawRead(buf, count)
    f.Close()
    out := ""
    Loop got
        out .= Format("{:02X}", NumGet(buf, A_Index-1, "UChar"))
    return out
}

WriteHex(path, offset, hex) {
    buf := HexToBuffer(hex)
    f := FileOpen(path, "rw")
    if !IsObject(f)
        throw Error("Impossible d'ouvrir le fichier en écriture.")
    f.Pos := offset
    f.RawWrite(buf, buf.Size)
    f.Close()
}

HexToBuffer(hex) {
    hex := RegExReplace(hex, "\s")
    if Mod(StrLen(hex), 2)
        throw Error("Chaîne hex invalide.")
    buf := Buffer(StrLen(hex)//2, 0)
    Loop buf.Size
        NumPut("UChar", Integer("0x" SubStr(hex, (A_Index-1)*2+1, 2)), buf, A_Index-1)
    return buf
}
