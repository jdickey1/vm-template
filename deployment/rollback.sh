#!/bin/bash

# Rollback script for Next.js application
set -e

echo "Starting rollback process..."

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
DEPLOY_DIR="/var/www/${PROJECT_NAME}"
BACKUP_DIR="/var/www/backups/${PROJECT_NAME}"
CURRENT_LINK="${DEPLOY_DIR}/current"

# Function to list available releases
list_releases() {
    echo "Available releases:"
    ls -lt ${DEPLOY_DIR}/releases | grep '^d' | awk '{print $9}' | head -n 5
}

# Function to list available backups
list_backups() {
    echo "Available backups:"
    ls -lt ${BACKUP_DIR} | grep '^d' | awk '{print $9}' | head -n 5
}

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [release|backup] [version]"
    echo "Example: $0 release 20230815_120000"
    echo "         $0 backup 20230815_120000"
    echo ""
    list_releases
    echo ""
    list_backups
    exit 1
fi

# Get current version for logging
CURRENT_VERSION=$(basename $(readlink ${CURRENT_LINK}))

# Perform rollback
if [ "$1" = "release" ]; then
    TARGET_DIR="${DEPLOY_DIR}/releases/$2"
elif [ "$1" = "backup" ]; then
    TARGET_DIR="${BACKUP_DIR}/$2"
else
    echo "Invalid option. Use 'release' or 'backup'"
    exit 1
fi

# Check if target exists
if [ ! -d "${TARGET_DIR}" ]; then
    echo "Error: Target version not found: $2"
    exit 1
fi

echo "Rolling back to $2..."

# Create backup of current version
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "Backing up current version..."
cp -r $(readlink ${CURRENT_LINK}) ${BACKUP_DIR}/${TIMESTAMP}_pre_rollback

# Update symlink
echo "Updating symlink to previous version..."
ln -sfn ${TARGET_DIR} ${CURRENT_LINK}

# Restart application
echo "Restarting application..."
if command -v pm2 &> /dev/null; then
    pm2 reload ${PROJECT_NAME}
else
    echo "PM2 not found. Please install PM2 first."
    exit 1
fi

echo "Rollback completed successfully!"

# Record rollback in log
echo "${TIMESTAMP}: Rolled back ${PROJECT_NAME} from ${CURRENT_VERSION} to $2" >> ${DEPLOY_DIR}/deploy.log

# Send notifications
if [ ! -z "${SLACK_WEBHOOK_URL}" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"⚠️ Rolled back ${PROJECT_NAME} to $2\"}" \
        ${SLACK_WEBHOOK_URL}
fi

if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Rollback completed for ${PROJECT_NAME} to version $2" | \
    mail -s "Rollback Notification" ${ADMIN_EMAIL}
fi