; Windows 11 Migration Tool - Inno Setup Installer Script
; Compile with Inno Setup 6+ (https://jrsoftware.org/isinfo.php)

#define MyAppName "Windows 11 Migration Tool"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Rory"
#define MyAppExeName "MigrationTool.cmd"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=MigrationTool_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "Migrate-Machine.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "MigrationTool-GUI.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "MigrationTool.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Migration Tool"; Flags: nowait postinstall skipifsilent runascurrentuser
