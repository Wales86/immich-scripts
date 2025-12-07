#!/bin/bash

# Default values
RASPBERRY_PI_HOST=""
USERNAME=""
PASSWORD=""
SSH_KEY="/home/wales/.ssh/id_ed25519"
REMOTE_PATH="/mnt/storage/backups/"
LOCAL_PATH="/mnt/d/backups/immich"
USE_PASSWORD=false
USE_KEY=true

# Function to display usage
usage() {
    echo "Usage: $0 -h <raspberry_pi_host> -u <username> [-p <password> | -k <key_file>] [-r <remote_path>] [-l <local_path>]"
    echo ""
    echo "Arguments:"
    echo "  -h    Raspberry Pi hostname or IP address (required)"
    echo "  -u    SSH username (required)"
    echo "  -p    SSH password (mutually exclusive with -k)"
    echo "  -k    SSH private key file path (mutually exclusive with -p)"
    echo "  -r    Remote backup directory path (default: /mnt/storage/backups/)"
    echo "  -l    Local destination directory (default: /mnt/d/backups/immich)"
    echo ""
    echo "Examples:"
    echo "  $0 -h 192.168.1.100 -u pi -p mypassword"
    echo "  $0 -h raspberrypi.local -u pi -k ~/.ssh/id_rsa"
    exit 1
}

# Parse command line arguments
while getopts "h:u:p:k:r:l:" opt; do
    case $opt in
        h) RASPBERRY_PI_HOST="$OPTARG" ;;
        u) USERNAME="$OPTARG" ;;
        p) PASSWORD="$OPTARG"; USE_PASSWORD=true ;;
        k) SSH_KEY="$OPTARG"; USE_KEY=true ;;
        r) REMOTE_PATH="$OPTARG" ;;
        l) LOCAL_PATH="$OPTARG" ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$RASPBERRY_PI_HOST" ] || [ -z "$USERNAME" ]; then
    echo "Error: Raspberry Pi host (-h) and username (-u) are required."
    usage
fi

# Validate authentication method
if [ "$USE_PASSWORD" = true ] && [ "$USE_KEY" = true ]; then
    echo "Error: Cannot use both password (-p) and key file (-k) authentication."
    usage
fi

if [ "$USE_PASSWORD" = false ] && [ "$USE_KEY" = false ]; then
    echo "Error: Must specify either password (-p) or key file (-k) for authentication."
    usage
fi

# Validate key file exists if using key authentication
if [ "$USE_KEY" = true ] && [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key file '$SSH_KEY' does not exist."
    exit 1
fi

# Remove trailing slashes from paths
REMOTE_PATH="${REMOTE_PATH%/}"
LOCAL_PATH="${LOCAL_PATH%/}"

# Create local directory if it doesn't exist
if [ ! -d "$LOCAL_PATH" ]; then
    echo "Creating local directory: $LOCAL_PATH"
    mkdir -p "$LOCAL_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create local directory $LOCAL_PATH"
        exit 1
    fi
fi

echo "Connecting to $RASPBERRY_PI_HOST as $USERNAME..."
echo "Remote path: $REMOTE_PATH"
echo "Local path: $LOCAL_PATH"

# Build SSH command options
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
if [ "$USE_KEY" = true ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
    echo "Using SSH key authentication: $SSH_KEY"
else
    echo "Using password authentication"
fi

# Function to execute SSH command
ssh_cmd() {
    if [ "$USE_PASSWORD" = true ]; then
        sshpass -p "$PASSWORD" ssh $SSH_OPTS "$USERNAME@$RASPBERRY_PI_HOST" "$1"
    else
        ssh $SSH_OPTS "$USERNAME@$RASPBERRY_PI_HOST" "$1"
    fi
}

# Function to execute SCP command
scp_cmd() {
    if [ "$USE_PASSWORD" = true ]; then
        sshpass -p "$PASSWORD" scp $SSH_OPTS "$1" "$2"
    else
        scp $SSH_OPTS "$1" "$2"
    fi
}

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh_cmd "echo 'SSH connection successful'" >/dev/null 2>&1; then
    echo "Error: Failed to establish SSH connection to $RASPBERRY_PI_HOST"
    exit 1
fi

# Find the latest file in remote directory
echo "Finding latest file in $REMOTE_PATH..."

# Get list of files with their modification times
LATEST_FILE=$(ssh_cmd "find '$REMOTE_PATH' -maxdepth 1 -type f -printf '%T@ %p\\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-")

if [ -z "$LATEST_FILE" ]; then
    echo "Error: No files found in $REMOTE_PATH or directory does not exist"
    exit 1
fi

# Get file details
FILE_NAME=$(basename "$LATEST_FILE")
FILE_SIZE=$(ssh_cmd "stat -c%s '$LATEST_FILE' 2>/dev/null")
FILE_MODTIME=$(ssh_cmd "stat -c%y '$LATEST_FILE' 2>/dev/null | cut -d'.' -f1")

echo "Latest file found: $FILE_NAME"
echo "File size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")"
echo "Last modified: $FILE_MODTIME"

# Download the file
LOCAL_FILE="$LOCAL_PATH/$FILE_NAME"
REMOTE_FILE="$USERNAME@$RASPBERRY_PI_HOST:$LATEST_FILE"

echo "Downloading $LATEST_FILE to $LOCAL_FILE..."

if scp_cmd "$REMOTE_FILE" "$LOCAL_FILE"; then
    echo "Download completed successfully!"

    # Verify the download
    if [ -f "$LOCAL_FILE" ]; then
        LOCAL_SIZE=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null)
        echo "Local file verified: $LOCAL_FILE"
        echo "Local file size: $(numfmt --to=iec-i --suffix=B $LOCAL_SIZE 2>/dev/null || echo "${LOCAL_SIZE} bytes")"

        if [ "$LOCAL_SIZE" = "$FILE_SIZE" ]; then
            echo "File size matches - download successful!"
        else
            echo "Warning: Local file size ($LOCAL_SIZE) does not match remote file size ($FILE_SIZE)"
        fi
    else
        echo "Error: Downloaded file not found locally"
        exit 1
    fi
else
    echo "Error: Failed to download file"
    exit 1
fi

echo "Script completed successfully"
