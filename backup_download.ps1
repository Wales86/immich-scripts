param(
    [Parameter(Mandatory=$true)]
    [string]$RaspberryPiHost,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [string]$Password,

    [string]$KeyFile,

    [string]$RemotePath = "/mnt/storage/backups/",

    [string]$LocalPath = "D:\backups\immich"
)

# Validate parameters
if ([string]::IsNullOrEmpty($RaspberryPiHost)) {
    Write-Error "RaspberryPiHost parameter is required"
    exit 1
}

if ([string]::IsNullOrEmpty($Username)) {
    Write-Error "Username parameter is required"
    exit 1
}

if ([string]::IsNullOrEmpty($LocalPath)) {
    Write-Error "LocalPath cannot be null or empty"
    exit 1
}

if ([string]::IsNullOrEmpty($RemotePath)) {
    Write-Error "RemotePath cannot be null or empty"
    exit 1
}

# Ensure local directory exists
if (!(Test-Path -Path $LocalPath)) {
    try {
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
        Write-Host "Created local directory: $LocalPath"
    } catch {
        Write-Error "Failed to create local directory '$LocalPath': $_"
        exit 1
    }
}

# Install Posh-SSH if not available
if (!(Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Installing Posh-SSH module..."
    try {
        Install-Module -Name Posh-SSH -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to install Posh-SSH module: $_"
        exit 1
    }
}

try {
    Import-Module Posh-SSH -ErrorAction Stop
} catch {
    Write-Error "Failed to import Posh-SSH module: $_"
    exit 1
}

# Create SSH session options
$sessionOptions = @{
    ComputerName = $RaspberryPiHost
}

# Handle authentication
if ($KeyFile -and (Test-Path $KeyFile)) {
    $sessionOptions.KeyFile = $KeyFile
    $sessionOptions.Credential = New-Object System.Management.Automation.PSCredential ($Username, (New-Object System.Security.SecureString))
    Write-Host "Using SSH key authentication: $KeyFile"
} elseif ($Password) {
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $sessionOptions.Credential = New-Object System.Management.Automation.PSCredential ($Username, $securePassword)
    Write-Host "Using password authentication"
} else {
    Write-Error "Please provide either a password (-Password) or SSH key file path (-KeyFile)"
    exit 1
}

try {
    # Establish SSH session
    Write-Host "Connecting to $RaspberryPiHost..."
    $session = New-SSHSession @sessionOptions -ErrorAction Stop

    if (!$session) {
        throw "Failed to establish SSH connection to $RaspberryPiHost"
    }

    Write-Host "Connected successfully. Session ID: $($session.SessionId)"

    # Create SFTP session
    Write-Host "Creating SFTP session..."
    
    $sftpOptions = @{
        ComputerName = $RaspberryPiHost
        Credential   = $sessionOptions.Credential
    }
    
    if ($sessionOptions.ContainsKey('KeyFile')) {
        $sftpOptions.KeyFile = $sessionOptions.KeyFile
    }

    $sftpSession = New-SFTPSession @sftpOptions -ErrorAction Stop

    if (!$sftpSession) {
        throw "Failed to establish SFTP session to $RaspberryPiHost"
    }

    Write-Host "SFTP session established. Listing files in $RemotePath..."

    # List files in remote directory
    try {
        $remoteFiles = Get-SFTPChildItem -SFTPSession $sftpSession -Path $RemotePath -ErrorAction Stop
    } catch {
        throw "Failed to list files in remote directory '$RemotePath': $_"
    }

    if ($remoteFiles.Count -eq 0) {
        Write-Host "No files found in $RemotePath"
        exit 0
    }

    # Filter only files (not directories) and find the latest one
    $filesOnly = $remoteFiles | Where-Object { !$_.IsDirectory }
    $latestFile = $filesOnly | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (!$latestFile) {
        Write-Host "No files found in $RemotePath (only directories present)"
        exit 0
    }

    Write-Host "Latest file found: $($latestFile.Name)"
    Write-Host "Last modified: $($latestFile.LastWriteTime)"
    Write-Host "File size: $([math]::Round($latestFile.Length / 1MB, 2)) MB"

    # Download the file
    $remoteFilePath = "$RemotePath$($latestFile.Name)"
    $localFilePath = Join-Path $LocalPath $latestFile.Name

    Write-Host "Downloading $remoteFilePath to $localFilePath..."
    Write-Host "This is a large file ($([math]::Round($latestFile.Length / 1GB, 2)) GB). Please be patient."

    try {
        # Try to use Get-SFTPFile if available
        if (Get-Command Get-SFTPFile -ErrorAction SilentlyContinue) {
            Get-SFTPFile -SFTPSession $sftpSession -RemoteFile $remoteFilePath -LocalPath $localFilePath -Overwrite -ErrorAction Stop
        } else {
            # Fallback for when Get-SFTPFile is missing (custom implementation using underlying stream)
            Write-Host "Using direct stream download..."
            
            $remoteStream = $sftpSession.Session.OpenRead($remoteFilePath)
            $localStream = [System.IO.File]::Create($localFilePath)
            
            # Use 1MB buffer for better performance with large files
            $bufferSize = 1MB
            $buffer = New-Object byte[] $bufferSize
            $totalRead = 0
            $totalSize = $latestFile.Length
            
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            
            while (($read = $remoteStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $localStream.Write($buffer, 0, $read)
                $totalRead += $read
                
                # Update progress
                if ($sw.ElapsedMilliseconds -gt 1000) {
                    $percent = ($totalRead / $totalSize) * 100
                    $speed = ($totalRead / 1MB) / $sw.Elapsed.TotalSeconds
                    Write-Progress -Activity "Downloading" -Status "$([math]::Round($percent, 2))% Complete - $([math]::Round($speed, 2)) MB/s" -PercentComplete $percent
                }
            }
            
            # Ensure 100% progress shown
            Write-Progress -Activity "Downloading" -Status "100% Complete" -PercentComplete 100
            
            $localStream.Close()
            $remoteStream.Close()
            $sw.Stop()
        }
    } catch {
        # Cleanup streams if they were opened
        if ($localStream) { $localStream.Close(); $localStream.Dispose() }
        if ($remoteStream) { $remoteStream.Close(); $remoteStream.Dispose() }
        throw "Failed to download file '$remoteFilePath' to '$localFilePath': $_"
    }

    Write-Host "Download completed successfully!"

    # Verify the download
    if (Test-Path $localFilePath) {
        $localFile = Get-Item $localFilePath
        Write-Host "Local file verified: $($localFile.FullName)"
        Write-Host "Local file size: $([math]::Round($localFile.Length / 1MB, 2)) MB"
    } else {
        throw "Downloaded file not found locally"
    }

} catch {
    Write-Error "An error occurred: $_"
    exit 1
} finally {
    # Clean up sessions
    if ($sftpSession) {
        Remove-SFTPSession -SFTPSession $sftpSession
        Write-Host "SFTP session closed"
    }

    if ($session) {
        Remove-SSHSession -SSHSession $session
        Write-Host "SSH session closed"
    }
}

Write-Host "Script completed successfully"
