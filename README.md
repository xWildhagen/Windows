# Windows

A centralized, modular repository managing Windows configuration, application provisioning, and environment setups, suitable for automated PC setups and ongoing system management.

## Features

- **Unattended Windows Setup**: Utilizes an `autounattend.xml` response file and PowerShell scripts to debloat, customize, and configure Windows _during_ the initial OOBE phase.
- **Modular Provisioning**: Configuration is broken down into discrete scopes (Settings, Applications, Package Management, User Profile data) via PowerShell scripts, allowing for flexible component-level updates.
- **Data-Driven Application Installs**: Direct downloads (`conf/apps.txt`) and Winget packages (`conf/winget.txt`) are maintained via simple text files.

## Prerequisites

Ensure you have the following ready before running any setup scripts:

- **Windows 10/11**
- **PowerShell 5.1+**
- **Git**
- **Winget** (App Installer from Microsoft Store)
- **OneDrive**: Logged into your primary account to pull and sync profile files if using `stuff.ps1`.

## Installation & Setup

### 1. (Optional) Zero-Touch Setup via AutoUnattend

For a fresh install of Windows, place the `autounattend.xml` file and the `scripts` directory on the root of your Windows installation media (USB). Windows Setup will parse the XML, bypass various hardware requirements, create a default user (`Wildhagen`), run a series of debloat scripts, and set initial system parameters before the first login.

### 2. Manual System Preparation

After a fresh install (or on an existing profile), ensure the base layer is up-to-date and necessary accounts are connected:

1. Log in to your Microsoft Account (if not using a local account).
2. Log in to OneDrive (syncs necessary configurations referenced by scripts).
3. Run Windows Update.
4. Run Microsoft Store updates.
5. Run Driver updates.

### 3. Clone the Repository

Open a PowerShell prompt, ensure Winget and Git are available, and clone this repository:

```powershell
winget update --all
winget install git.git
git clone https://github.com/xWildhagen/Windows
cd Windows
```

## Usage

To manage your configuration, use the following scripts located in the `scripts` directory. You can run them individually to pick and choose components, or use the interactive menus provided within each script to run everything at once.

```powershell
# 1. Update system settings (display, power, appearance, WSL/Hyper-V)
.\scripts\settings.ps1

# 2. Install applications via direct download links from apps.txt
.\scripts\apps.ps1

# 3. Install packages via Winget based on IDs from winget.txt
.\scripts\winget.ps1

# 4. Restore configurations (Terminal, Edge profiles, SSH keys, .gitconfig) from OneDrive
.\scripts\stuff.ps1
```

## Missing Configuration

The following settings still need to be applied manually via the Windows UI:

### Settings

- System > Display > Night light
- System > Display > Advanced display
- System > Sound
- Personalisation > Colours > Accent colour (`#7A6D98` or `#686BC6`)
- Accounts > Sign-in options
- Time & Language > Language & region

### Other

- Configure Windows Security exclusions/preferences
- Attach Network Attached Storage (NAS)
- Rearrange taskbar icons manually

---

_Tip: To pull the latest changes from GitHub locally, run:_

```powershell
git -C windows pull
git -C windows reset --hard
```
