#ifndef AppVersion
  #error AppVersion must be supplied by the release workflow
#endif
#ifndef OutputName
  #error OutputName must be supplied by the release workflow
#endif

[Setup]
AppId={{41411C45-9022-4189-B2D5-4D4484C32376}
AppName=RN Network Viewer
AppVersion={#AppVersion}
AppPublisher=DevMobileAn27
AppPublisherURL=https://github.com/DevMobileAn27/rn_network_viewer
DefaultDirName={localappdata}\Programs\RN Network Viewer
DefaultGroupName=RN Network Viewer
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\release
OutputBaseFilename={#OutputName}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rn_network_viewer.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\RN Network Viewer"; Filename: "{app}\rn_network_viewer.exe"

[Run]
Filename: "{app}\rn_network_viewer.exe"; Flags: nowait runasoriginaluser
