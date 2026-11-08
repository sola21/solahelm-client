; Windows installer (Inno Setup 6), built by tools\package-windows.ps1:
;   ISCC /DAppVersion=0.2.2 /DSourceDir=<folder with the app> tools\windows-setup.iss
; Installs for the current user, no administrator rights needed, into
; %LOCALAPPDATA%\Programs\SolaHelm. Settings and subscriptions stay in
; %APPDATA%\solahelm-client and survive updates and uninstalling.
; The client updates itself by running the next setup with /VERYSILENT.

#ifndef AppVersion
  #error Pass /DAppVersion=x.y.z
#endif
#ifndef SourceDir
  #error Pass /DSourceDir=<folder with solahelm_client.exe>
#endif

[Setup]
AppId={{06AF35B7-F1DD-4902-AFF7-9A7801D2499D}
AppName=SolaHelm Client
AppVersion={#AppVersion}
AppVerName=SolaHelm Client {#AppVersion}
AppPublisher=sola21
AppPublisherURL=https://github.com/sola21/solahelm-client
AppSupportURL=https://github.com/sola21/solahelm-client/issues
AppUpdatesURL=https://github.com/sola21/solahelm-client/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\SolaHelm
DefaultGroupName=SolaHelm
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=SolaHelm-{#AppVersion}-windows-x64-setup
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\solahelm_client.exe
UninstallDisplayName=SolaHelm Client
LicenseFile=..\LICENSE
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Closes a running client (and its core) before replacing the files.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "portable.txt"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SolaHelm"; Filename: "{app}\solahelm_client.exe"
Name: "{autodesktop}\SolaHelm"; Filename: "{app}\solahelm_client.exe"; Tasks: desktopicon

[Registry]
; The client's own "start with Windows" entry: removed together with the program.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "SolaHelm"; ValueType: none; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\solahelm_client.exe"; Description: "{cm:LaunchProgram,SolaHelm}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop the client so its files can be removed. The core notices the client is
; gone and stops by itself, restoring the system proxy settings; only a core
; left running on purpose ("exit, keep the VPN on") is stopped by force after
; a short wait.
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM solahelm_client.exe"; Flags: runhidden; RunOnceId: "StopClient"
Filename: "{sys}\ping.exe"; Parameters: "-n 4 127.0.0.1"; Flags: runhidden; RunOnceId: "WaitCore"
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM solahelm-core.exe"; Flags: runhidden; RunOnceId: "StopCore"
