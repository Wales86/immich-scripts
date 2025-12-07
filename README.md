# immich-scripts

Scripts for managing Immich backups and related operations.

## backup_download.ps1 - PowerShell Backup Downloader

Downloads the latest backup file from a Raspberry Pi to local storage.

### Usage

First, ensure PowerShell execution policy allows script running:

```powershell
# Option 1: Run with execution policy bypass (recommended for one-time use)
PowerShell.exe -ExecutionPolicy Bypass -File .\backup_download.ps1 [parameters]

# Option 2: Change execution policy for current session
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Option 3: Change execution policy permanently (use with caution)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script:

```powershell
# Using password authentication
.\backup_download.ps1 -RaspberryPiHost "192.168.1.100" -Username "pi" -Password "your_password"

# Using SSH key authentication
.\backup_download.ps1 -RaspberryPiHost "192.168.1.100" -Username "pi" -KeyFile "C:\path\to\your\private\key"

# Custom paths
.\backup_download.ps1 -RaspberryPiHost "192.168.1.100" -Username "pi" -Password "your_password" -RemotePath "/mnt/storage/backups/" -LocalPath "D:\backups\immich"
```

### Parameters

- `RaspberryPiHost` (Required): IP address or hostname of the Raspberry Pi
- `Username` (Required): SSH username (usually 'pi')
- `Password`: SSH password (if not using key authentication)
- `KeyFile`: Path to SSH private key file (alternative to password)
- `RemotePath`: Remote directory path (default: "/mnt/storage/backups/")
- `LocalPath`: Local destination directory (default: "D:\backups\immich")

### Requirements

- PowerShell 5.1 or higher
- Posh-SSH module (will be installed automatically if missing)
- SSH access to the Raspberry Pi

### Features

- Automatically finds and downloads the latest file from the backup directory
- Supports both password and SSH key authentication
- Creates local directory if it doesn't exist
- Verifies download completion
- Proper error handling and session cleanup
- Comprehensive parameter validation

### Troubleshooting

**Execution Policy Error:**
```powershell
# Use bypass for one-time execution
PowerShell.exe -ExecutionPolicy Bypass -File .\backup_download.ps1 [parameters]
```

**Connection Issues:**
- Ensure SSH is enabled on your Raspberry Pi
- Verify hostname/IP address is correct
- Check that username and authentication credentials are valid
- Make sure the remote path exists on the Raspberry Pi

**Module Installation Issues:**
```powershell
# Install Posh-SSH manually if needed
Install-Module -Name Posh-SSH -Scope CurrentUser -Force
```

## backup_download.sh - Bash Backup Downloader

Downloads the latest backup file from a Raspberry Pi to local storage (Linux/WSL version).

### Usage

```bash
# Using password authentication (requires sshpass)
./backup_download.sh -h 192.168.1.100 -u pi -p your_password

# Using SSH key authentication
./backup_download.sh -h 192.168.1.100 -u pi -k ~/.ssh/id_rsa

# Custom paths
./backup_download.sh -h 192.168.1.100 -u pi -p your_password -r /mnt/storage/backups/ -l /mnt/d/backups/immich
```

### Arguments

- `-h` (Required): Raspberry Pi hostname or IP address
- `-u` (Required): SSH username (usually 'pi')
- `-p`: SSH password (mutually exclusive with -k, requires sshpass)
- `-k`: SSH private key file path (mutually exclusive with -p)
- `-r`: Remote directory path (default: "/mnt/storage/backups/")
- `-l`: Local destination directory (default: "/mnt/d/backups/immich")

### Requirements

- Bash shell
- OpenSSH client (ssh, scp)
- sshpass (only if using password authentication)
- SSH access to the Raspberry Pi

### Features

- Automatically finds and downloads the latest file from the backup directory
- Supports both password and SSH key authentication
- Creates local directory if it doesn't exist
- Verifies download completion and file integrity
- Proper error handling and connection testing
