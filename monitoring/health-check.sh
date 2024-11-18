#!/bin/bash
set -e

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"nextjs-app"}
APP_URL=${APP_URL:-"http://localhost:3000"}
METRICS_PORT=${METRICS_PORT:-9209}
ALERT_WEBHOOK=${ALERT_WEBHOOK:-""}
LOG_FILE="/var/www/${PROJECT_NAME}/shared/logs/health-check.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send alerts
send_alert() {
    local severity=$1
    local message=$2
    
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"severity\": \"$severity\", \"message\": \"$message\", \"service\": \"$PROJECT_NAME\"}"
    fi
    
    log "[ALERT] [$severity] $message"
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # Check CPU load
    cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    if (( $(echo "$cpu_load > 4" | bc -l) )); then
        send_alert "warning" "High CPU load: $cpu_load"
    fi
    
    # Check memory usage
    memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        send_alert "warning" "High memory usage: ${memory_usage}%"
    fi
    
    # Check disk usage
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 85 ]; then
        send_alert "warning" "High disk usage: ${disk_usage}%"
    fi
}

# Check application status
check_application() {
    log "Checking application status..."
    
    # Check if PM2 process is running
    if ! pm2 show "$PROJECT_NAME" > /dev/null 2>&1; then
        send_alert "critical" "Application process is not running"
        exit 1
    fi
    
    # Check application health endpoint
    response=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/health")
    if [ "$response" != "200" ]; then
        send_alert "critical" "Health check failed with status $response"
        exit 1
    fi
    
    # Check metrics endpoint
    metrics_response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$METRICS_PORT/metrics")
    if [ "$metrics_response" != "200" ]; then
        send_alert "warning" "Metrics endpoint check failed with status $metrics_response"
    fi
}

# Check database connection
check_database() {
    log "Checking database connection..."
    
    # Check PostgreSQL connection
    if ! psql -U "$PROJECT_NAME" -d "$PROJECT_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        send_alert "critical" "Database connection failed"
        exit 1
    fi
    
    # Check for long-running queries
    long_queries=$(psql -U "$PROJECT_NAME" -d "$PROJECT_NAME" -c "
        SELECT pid, now() - query_start as duration, query 
        FROM pg_stat_activity 
        WHERE state != 'idle' 
        AND now() - query_start > interval '5 minutes';" -t)
    
    if [ -n "$long_queries" ]; then
        send_alert "warning" "Long-running queries detected: $long_queries"
    fi
}

# Check SSL certificate
check_ssl() {
    log "Checking SSL certificate..."
    
    domain=$(echo "$APP_URL" | awk -F[/:] '{print $4}')
    if [ -n "$domain" ] && [ "$domain" != "localhost" ]; then
        expiry_date=$(openssl s_client -connect "$domain":443 -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ "$days_until_expiry" -lt 30 ]; then
            send_alert "warning" "SSL certificate will expire in $days_until_expiry days"
        fi
    fi
}

# Check backup status
check_backups() {
    log "Checking backup status..."
    
    # Check for recent database backup
    latest_backup=$(find /var/lib/postgresql/backups -type f -name "*.dump" -mtime -1 | head -n 1)
    if [ -z "$latest_backup" ]; then
        send_alert "warning" "No recent database backup found"
    fi
    
    # Check backup size
    if [ -n "$latest_backup" ]; then
        backup_size=$(du -h "$latest_backup" | cut -f1)
        log "Latest backup size: $backup_size"
    fi
}

# Main health check routine
main() {
    log "Starting health check for $PROJECT_NAME"
    
    check_system_resources
    check_application
    check_database
    check_ssl
    check_backups
    
    log "Health check completed successfully"
}

# Run main routine
main "$@"
