# Eyebreak

A minimalist, lightweight tool designed to reduce eye strain

[![macOS](https://img.shields.io/badge/macOS-Apple%20Silicon-blue?logo=apple&style=flat-square)](#compatibility)
![Release](https://img.shields.io/badge/release-v1.2-brightgreen?style=flat-square)
[![License](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)](#license)
[![Built with Swift](https://img.shields.io/badge/Built%20with-Swift-FA7343?style=flat-square&logo=swift&logoColor=white)](#)

<img width="1202" height="272" alt="demo" src="https://github.com/user-attachments/assets/097924d6-5362-4e0c-a2a1-441634c3ff17" />

What the menu bar looks like:

<img width="109" height="32" alt="Screenshot 2026-09-11 at 7 28 09 pm" src="https://github.com/user-attachments/assets/ec29eb25-0d19-4ea6-a0a5-d131dd4e6d25" />

# Specs:
- Uses around 1.5% CPU
- 10 MB of memory

# Features:
- A small notice will popup when the time is up
- Menu bar icon for easy use
- Click menu bar icon to pause
- Right click for options like reset and quit
- Left click the message to dismiss 
- Double click the icon to expand and collapse (v1.2)
- Optimized further (v1.2)
- Added haptics (v1.2)
- Music plays when break is up (v1.2)


# Credits
Code by me.

Menu bar icon sourced from [SVG Repo](https://www.svgrepo.com/).

Short music from Andrew Applepie - Berlin

# Installation
1. Download the latest release:

   [![Download for macOS](https://img.shields.io/badge/Download_for_macOS-Latest_Release-1d1d1f?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/sigma-prog/Eyebreak/releases/latest)

2. Unzip and drag **`EyeBreak.app`** into your **`/Applications`** folder.

> **Note for macOS Gatekeeper:**  
> If macOS says the app *"can't be opened because Apple cannot check it for malicious software"*, open your Terminal and run:
> ```bash
> xattr -cr /Applications/EyeBreak.app
> ```

The download is only for mac M series chips only (M1, M2 , M3 ...), intel chips won't work.

This project is licensed under the MIT License

# Compiling

If you are on an Intel Mac or prefer compiling yourself:

```bash
git clone https://github.com/sigma-prog/Eyebreak.git
cd Eyebreak
swiftc src/*.swift -o EyeBreak && ./EyeBreak &
