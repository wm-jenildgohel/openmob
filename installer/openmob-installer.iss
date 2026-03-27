; OpenMob Windows Installer — Inno Setup Script
; Bundles Hub + MCP Server + AiBridge into a single installer
; Built by CI: iscc /DMyAppVersion=X.Y.Z openmob-installer.iss

#ifndef MyAppVersion
  #define MyAppVersion "0.0.9"
#endif

#define MyAppName "OpenMob"
#define MyAppPublisher "OpenMob"
#define MyAppURL "https://github.com/wm-jenildgohel/openmob"
#define MyAppExeName "openmob_hub.exe"

[Setup]
AppId={{B8F4A2E1-7C3D-4E5F-9A1B-2D6E8F0C3A7B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\installer-output
OutputBaseFilename=OpenMob-Setup-{#MyAppVersion}-x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesEnvironment=yes
SetupIconFile=..\openmob_hub\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
LicenseFile=..\LICENSE
; Use default wizard images (built into Inno Setup)
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "addtopath"; Description: "Add OpenMob tools to PATH (for terminal use)"; GroupDescription: "Developer Options:"

[Files]
; Flutter Hub — all files from Release build
Source: "..\build\hub-windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; MCP Server binary (standalone, no Node.js needed)
Source: "..\build\mcp-windows\openmob-mcp.exe"; DestDir: "{app}"; Flags: ignoreversion

; AiBridge binary
Source: "..\build\bridge-windows\aibridge.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "AI Mobile Device Automation"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "AI Mobile Device Automation"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Code]
// PATH modification — adds {app} to user PATH so aibridge is accessible from terminal
const
  EnvironmentKey_User = 'Environment';
  EnvironmentKey_Machine = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

var
  OrigPath: string;

function NeedsAddPath(Param: string): boolean;
var
  ParamExpanded: string;
  CurrentPath: string;
begin
  ParamExpanded := ExpandConstant(Param);
  // Check user PATH
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', CurrentPath) then
    CurrentPath := '';
  Result := Pos(';' + Uppercase(ParamExpanded) + ';', ';' + Uppercase(CurrentPath) + ';') = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  CurrentPath: string;
begin
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('addtopath') and NeedsAddPath('{app}') then
    begin
      if RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', CurrentPath) then
        RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', CurrentPath + ';' + ExpandConstant('{app}'))
      else
        RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', ExpandConstant('{app}'));
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  CurrentPath: string;
  AppDir: string;
  P: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    if RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', CurrentPath) then
    begin
      P := Pos(';' + Uppercase(AppDir), Uppercase(CurrentPath));
      if P > 0 then
      begin
        Delete(CurrentPath, P, Length(AppDir) + 1);
        RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey_User, 'Path', CurrentPath);
      end;
    end;
  end;
end;
