#!/bin/bash

# PostgreSQL Backup Script
set -e

echo "Starting database backup..."

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
BACKUP_DIR="/var/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME=${DB_NAME:-nextjs}
BACKUP_DAYS=7
BACKUP_WEEKS=4
BACKUP_MONTHS=3
LOG_FILE="/var/log/postgresql/backup.log"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"
mkdir -p "${BACKUP_DIR}/monthly"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo "$1"
}

# Function to create backup
create_backup() {
    local backup_type=$1
    local backup_file="${BACKUP_DIR}/${backup_type}/${DB_NAME}_${backup_type}_${TIMESTAMP}.sql.gz"
    
    log_message "Creating ${backup_type} backup: ${backup_file}"
    
    # Create backup
    PGPASSWORD="${DB_PASSWORD}" pg_dump -h localhost -U "${DB_USER:-nextjs}" \
        -F p "${DB_NAME}" | gzip > "${backup_file}"
    
    # Check if backup was successful
    if [ $? -eq 0 ]; then
        log_message "Backup completed successfully"
        
        # Create SHA256 checksum
        sha256sum "${backup_file}" > "${backup_file}.sha256"
        
        # Set permissions
        chmod 600 "${backup_file}"
        chmod 600 "${backup_file}.sha256"
        chown postgres:postgres "${backup_file}"
        chown postgres:postgres "${backup_file}.sha256"
    else
        log_message "Backup failed"
        rm -f "${backup_file}"
        exit 1
    fi
}

# Function to cleanup old backups
cleanup_backups() {
    local backup_type=$1
    local days=$2
    local backup_dir="${BACKUP_DIR}/${backup_type}"
    
    log_message "Cleaning up old ${backup_type} backups..."
    find "${backup_dir}" -type f -name "*.sql.gz" -mtime "+${days}" -delete
    find "${backup_dir}" -type f -name "*.sha256" -mtime "+${days}" -delete
}

# Function to verify backup
verify_backup() {
    local backup_file=$1
    local checksum_file="${backup_file}.sha256"
    
    if [ -f "${checksum_file}" ]; then
        log_message "Verifying backup: ${backup_file}"
        if sha256sum -c "${checksum_file}" > /dev/null 2>&1; then
            log_message "Backup verification successful"
            return 0
        else
            log_message "Backup verification failed"
            return 1
        fi
    else
        log_message "Checksum file not found: ${checksum_file}"
        return 1
    fi
}

# Function to upload backup to remote server (if configured)
upload_backup() {
    local backup_file=$1
    if [ ! -z "${REMOTE_BACKUP_HOST}" ] && [ ! -z "${REMOTE_BACKUP_PATH}" ]; then
        log_message "Uploading backup to remote server..."
        rsync -avz -e "ssh -p ${REMOTE_BACKUP_PORT:-22}" \
            "${backup_file}" \
            "${REMOTE_BACKUP_USER}@${REMOTE_BACKUP_HOST}:${REMOTE_BACKUP_PATH}/"
        
        if [ $? -eq 0 ]; then
            log_message "Remote backup successful"
        else
            log_message "Remote backup failed"
        fi
    fi
}

# Create backups based on schedule
case "${1:-daily}" in
    "daily")
        create_backup "daily"
        cleanup_backups "daily" "${BACKUP_DAYS}"
        ;;
    "weekly")
        create_backup "weekly"
        cleanup_backups "weekly" "$((BACKUP_WEEKS * 7))"
        ;;
    "monthly")
        create_backup "monthly"
        cleanup_backups "monthly" "$((BACKUP_MONTHS * 30))"
        ;;
    *)
        echo "Invalid backup type. Use: daily, weekly, or monthly"
        exit 1
        ;;
esac

# Verify latest backup
latest_backup=$(ls -t "${BACKUP_DIR}/${1:-daily}"/*.sql.gz 2>/dev/null | head -n1)
if [ ! -z "${latest_backup}" ]; then
    verify_backup "${latest_backup}"
    if [ $? -eq 0 ] && [ ! -z "${REMOTE_BACKUP_HOST}" ]; then
        upload_backup "${latest_backup}"
    fi
fi

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Database backup completed. Check ${LOG_FILE} for details." | \
    mail -s "Database Backup Notification" ${ADMIN_EMAIL}
fi

log_message "Backup process completed"