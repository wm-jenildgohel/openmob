# Building OpenMob Hub for Windows

The Hub desktop app must be built on a Windows machine (Flutter doesn't support Windows cross-compilation from Linux).

## Steps (on a Windows PC)

1. Install Flutter: https://docs.flutter.dev/get-started/install/windows
2. Clone the repo and build:

```powershell
cd openmob_hub
flutter build windows --release
```

3. Copy the built files into this folder:

```powershell
copy build\windows\x64\runner\Release\* dist\openmob-windows-x64\
```

The built output includes `openmob_hub.exe` and required DLLs.

## After building

Double-click `openmob.bat` to start everything.
