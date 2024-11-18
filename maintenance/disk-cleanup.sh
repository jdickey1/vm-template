#!/bin/bash
set -e

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"nextjs-app"}
PROJECT_ROOT="/var/www/${PROJECT_NAME}"
LOG_FILE="${PROJECT_ROOT}/shared/logs/disk-cleanup.log"
KEEP_RELEASES=5
KEEP_LOGS_DAYS=30
KEEP_TEMP_DAYS=7
MIN_FREE_SPACE=20  # Minimum free space percentage

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check disk space
check_disk_space() {
    local mount_point=$1
    local free_space=$(df -h "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')
    local used_space=$((100 - free_space))
    
    if [ "$used_space" -gt "$((100 - MIN_FREE_SPACE))" ]; then
        log "WARNING: Low disk space on $mount_point: $free_space% free"
        return 1
    fi
    return 0
}

# Clean old releases
clean_releases() {
    log "Cleaning old releases..."
    
    cd "${PROJECT_ROOT}/releases" || exit 1
    
    # Keep only the last N releases
    ls -t | tail -n +$((KEEP_RELEASES + 1)) | while read -r release; do
        log "Removing old release: $release"
        rm -rf "$release"
    done
}

# Clean application logs
clean_app_logs() {
    log "Cleaning application logs..."
    
    # Clean old PM2 logs
    find "${PROJECT_ROOT}/shared/logs" -name "*.log" -type f -mtime +"$KEEP_LOGS_DAYS" -delete
    
    # Clean rotated logs
    find "${PROJECT_ROOT}/shared/logs" -name "*.gz" -type f -mtime +"$KEEP_LOGS_DAYS" -delete
    
    # Clean empty log files
    find "${PROJECT_ROOT}/shared/logs" -type f -empty -delete
}

# Clean system logs
clean_system_logs() {
    log "Cleaning system logs..."
    
    # Clean old system logs
    sudo find /var/log -type f -name "*.gz" -mtime +"$KEEP_LOGS_DAYS" -delete
    sudo find /var/log -type f -name "*.old" -mtime +"$KEEP_LOGS_DAYS" -delete
    
    # Clean journal logs
    sudo journalctl --vacuum-time="${KEEP_LOGS_DAYS}days"
}

# Clean temporary files
clean_temp_files() {
    log "Cleaning temporary files..."
    
    # Clean /tmp directory
    sudo find /tmp -type f -atime +"$KEEP_TEMP_DAYS" -delete
    
    # Clean application temp files
    find "${PROJECT_ROOT}/shared/tmp" -type f -mtime +"$KEEP_TEMP_DAYS" -delete
}

# Clean package manager cache
clean_package_cache() {
    log "Cleaning package manager cache..."
    
    # Clean npm cache
    npm cache clean --force
    
    # Clean yarn cache
    yarn cache clean
    
    # Clean apt cache
    sudo apt-get clean
    sudo apt-get autoremove -y
}

# Clean build artifacts
clean_build_artifacts() {
    log "Cleaning build artifacts..."
    
    # Clean Next.js build cache
    find "${PROJECT_ROOT}/current/.next/cache" -type f -mtime +"$KEEP_TEMP_DAYS" -delete
    
    # Clean node_modules in old releases
    cd "${PROJECT_ROOT}/releases" || exit 1
    ls -t | tail -n +$((KEEP_RELEASES + 1)) | while read -r release; do
        if [ -d "$release/node_modules" ]; then
            log "Removing node_modules from old release: $release"
            rm -rf "$release/node_modules"
        fi
    done
}

# Clean database
clean_database() {
    log "Cleaning database..."
    
    # Vacuum database
    sudo -u postgres psql -d "$PROJECT_NAME" -c "VACUUM FULL ANALYZE;"
    
    # Clean old database dumps
    find /var/lib/postgresql/backups -type f -name "*.dump" -mtime +"$KEEP_LOGS_DAYS" -delete
}

# Main cleanup routine
main() {
    log "Starting disk cleanup for $PROJECT_NAME"
    
    # Initial disk space check
    initial_space=$(df -h / | tail -1 | awk '{print $5}')
    log "Initial disk usage: $initial_space"
    
    # Perform cleanup tasks
    clean_releases
    clean_app_logs
    clean_system_logs
    clean_temp_files
    clean_package_cache
    clean_build_artifacts
    clean_database
    
    # Final disk space check
    final_space=$(df -h / | tail -1 | awk '{print $5}')
    log "Final disk usage: $final_space"
    
    # Check if we need to alert about low disk space
    if ! check_disk_space /; then
        # Send alert or notification here
        log "ALERT: Low disk space after cleanup"
    fi
    
    log "Disk cleanup completed successfully"
}

# Run main routine
main "$@"
