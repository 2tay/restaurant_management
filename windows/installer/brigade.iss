; The Windows installer for Brigade (Inno Setup 6).
;
; Builds release\Brigade-<version>\Brigade-Setup-<version>.exe from the
; release build, so build that first:
;
;   flutter build windows --release --dart-define-from-file=config/dev.json
;   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" /DAppVersion=1.0.0 windows\installer\brigade.iss
;
; Installs for the current Windows user only: no administrator password, the
; app goes to %LOCALAPPDATA%\Programs\Brigade, with a Start menu entry, a
; desktop icon and an entry in Settings → Apps to uninstall it. Running a newer
; installer updates it in place; the data lives elsewhere and is kept, also on
; uninstall.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Never change AppId: it is how a newer installer finds the installed app.
AppId={{068A79E8-EA15-4099-9BB5-9B4BCC1471EE}
AppName=Brigade
AppVersion={#AppVersion}
AppVerName=Brigade {#AppVersion}
AppPublisher=Brigade
DefaultDirName={autopf}\Brigade
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Brigade.exe
UninstallDisplayName=Brigade
WizardStyle=modern
ShowLanguageDialog=no
CloseApplications=yes
OutputDir=..\..\release\Brigade-{#AppVersion}
OutputBaseFilename=Brigade-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs
; The 64-bit Visual C++ runtime next to the app, for PCs that do not have it.
; Sysnative: the compiler is 32-bit, and System32 would give it the 32-bit DLLs.
Source: "C:\Windows\Sysnative\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Windows\Sysnative\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Windows\Sysnative\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Brigade"; Filename: "{app}\Brigade.exe"
Name: "{autodesktop}\Brigade"; Filename: "{app}\Brigade.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Brigade.exe"; Description: "{cm:LaunchProgram,Brigade}"; Flags: nowait postinstall skipifsilent
