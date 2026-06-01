Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("Shell.Application")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
shell.ShellExecute "powershell.exe", "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & scriptDir & "\PCmigrate-GUI.ps1""", "", "runas", 0
