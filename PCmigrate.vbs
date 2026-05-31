Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("Shell.Application")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
styleFile = scriptDir & "\.pcmigrate-style"
guiScript = "PCmigrate-GUI.ps1"

If fso.FileExists(styleFile) Then
    Set f = fso.OpenTextFile(styleFile, 1)
    style = Trim(f.ReadLine())
    f.Close
    If LCase(style) = "retro" Then guiScript = "PCmigrate-Retro.ps1"
End If

shell.ShellExecute "powershell.exe", "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & scriptDir & "\" & guiScript & """", "", "runas", 0
