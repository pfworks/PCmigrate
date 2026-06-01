; Windows Migration Tool - Inno Setup Installer Script
; Compile with Inno Setup 6+ (https://jrsoftware.org/isinfo.php)

#define MyAppName "Windows Migration Tool"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Rory"
#define MyAppExeName "PCmigrate.vbs"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=PCmigrate_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=PCmigrate.ico
UninstallDisplayIcon={app}\PCmigrate.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "Migrate-Machine.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "PCmigrate-GUI.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "PCmigrate.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "PCmigrate.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "PCmigrate.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""{app}\PCmigrate-GUI.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\PCmigrate.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""{app}\PCmigrate-GUI.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\PCmigrate.ico"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""{app}\PCmigrate-GUI.ps1"""; Description: "Launch PCmigrate"; Flags: nowait postinstall skipifsilent runascurrentuser
