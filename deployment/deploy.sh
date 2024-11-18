#!/bin/bash

# Zero-downtime deployment script for Next.js application
set -e

echo "Starting deployment process..."

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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RELEASE_DIR="${DEPLOY_DIR}/releases/${TIMESTAMP}"
CURRENT_LINK="${DEPLOY_DIR}/current"

# Create necessary directories
mkdir -p ${DEPLOY_DIR}/releases
mkdir -p ${BACKUP_DIR}

# Clone/pull latest code
echo "Fetching latest code..."
if [ -d "${DEPLOY_DIR}/repo" ]; then
    cd "${DEPLOY_DIR}/repo"
    git fetch origin
    git reset --hard origin/main
else
    git clone ${GITHUB_REPO} "${DEPLOY_DIR}/repo"
    cd "${DEPLOY_DIR}/repo"
fi

# Create new release directory
echo "Creating new release..."
mkdir -p ${RELEASE_DIR}
cp -r ${DEPLOY_DIR}/repo/* ${RELEASE_DIR}/

# Install dependencies
echo "Installing dependencies..."
cd ${RELEASE_DIR}
npm install --production

# Build application
echo "Building application..."
npm run build

# Backup current release
if [ -L ${CURRENT_LINK} ]; then
    CURRENT_RELEASE=$(readlink ${CURRENT_LINK})
    if [ -d "${CURRENT_RELEASE}" ]; then
        echo "Backing up current release..."
        cp -r ${CURRENT_RELEASE} ${BACKUP_DIR}/${TIMESTAMP}
    fi
fi

# Update symlink
echo "Updating symlink..."
ln -sfn ${RELEASE_DIR} ${CURRENT_LINK}

# Reload application
echo "Reloading application..."
if command -v pm2 &> /dev/null; then
    pm2 reload ${PROJECT_NAME} || pm2 start npm --name "${PROJECT_NAME}" -- start
else
    echo "PM2 not found. Please install PM2 first."
    exit 1
fi

# Cleanup old releases (keep last 5)
echo "Cleaning up old releases..."
cd ${DEPLOY_DIR}/releases
ls -t | tail -n +6 | xargs -r rm -rf

# Cleanup old backups (keep last 5)
cd ${BACKUP_DIR}
ls -t | tail -n +6 | xargs -r rm -rf

echo "Deployment completed successfully!"

# Record deployment in log
echo "${TIMESTAMP}: Deployed ${PROJECT_NAME} from ${GITHUB_REPO}" >> ${DEPLOY_DIR}/deploy.log

# Notify about deployment
if [ ! -z "${SLACK_WEBHOOK_URL}" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ Successfully deployed ${PROJECT_NAME} (${TIMESTAMP})\"}" \
        ${SLACK_WEBHOOK_URL}
fi

if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Deployment successful for ${PROJECT_NAME} (${TIMESTAMP})" | \
    mail -s "Deployment Notification" ${ADMIN_EMAIL}
fi