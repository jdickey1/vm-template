#!/bin/bash

# PostgreSQL Maintenance Script
set -e

echo "Starting database maintenance..."

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
DB_NAME=${DB_NAME:-nextjs}
LOG_FILE="/var/log/postgresql/maintenance.log"
VACUUM_TYPE=${1:-"full"}  # Options: full, analyze
TABLE_NAME=$2            # Optional: specific table name

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo "$1"
}

# Function to check database size
check_db_size() {
    log_message "Checking database size..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "\l+ ${DB_NAME}" | grep -v rows | grep "${DB_NAME}"
}

# Function to check table sizes
check_table_sizes() {
    log_message "Checking table sizes..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "
        SELECT 
            schemaname as schema,
            relname as table,
            pg_size_pretty(pg_total_relation_size(relid)) as total_size,
            pg_size_pretty(pg_relation_size(relid)) as data_size,
            pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as external_size
        FROM pg_catalog.pg_statio_user_tables 
        ORDER BY pg_total_relation_size(relid) DESC;
    "
}

# Function to check index usage
check_index_usage() {
    log_message "Checking index usage..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "
        SELECT 
            schemaname as schema,
            relname as table,
            indexrelname as index,
            idx_scan as number_of_scans,
            idx_tup_read as tuples_read,
            idx_tup_fetch as tuples_fetched
        FROM pg_stat_user_indexes
        ORDER BY idx_scan DESC;
    "
}

# Function to perform vacuum
perform_vacuum() {
    local vacuum_type=$1
    local table_name=$2
    
    if [ "${vacuum_type}" = "full" ]; then
        log_message "Performing VACUUM FULL..."
        if [ -z "${table_name}" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
                -d "${DB_NAME}" -c "VACUUM FULL VERBOSE ANALYZE;"
        else
            PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
                -d "${DB_NAME}" -c "VACUUM FULL VERBOSE ANALYZE ${table_name};"
        fi
    else
        log_message "Performing VACUUM ANALYZE..."
        if [ -z "${table_name}" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
                -d "${DB_NAME}" -c "VACUUM ANALYZE VERBOSE;"
        else
            PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
                -d "${DB_NAME}" -c "VACUUM ANALYZE VERBOSE ${table_name};"
        fi
    fi
}

# Function to check for long-running queries
check_long_queries() {
    log_message "Checking for long-running queries..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "
        SELECT 
            pid,
            now() - pg_stat_activity.query_start AS duration,
            query,
            state
        FROM pg_stat_activity
        WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
        ORDER BY duration DESC;
    "
}

# Function to analyze query performance
analyze_queries() {
    log_message "Analyzing query performance..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "
        SELECT 
            substring(query, 1, 50) as query_preview,
            calls,
            total_time,
            mean_time,
            rows
        FROM pg_stat_statements
        ORDER BY total_time DESC
        LIMIT 10;
    "
}

# Function to reindex database
reindex_database() {
    log_message "Reindexing database..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" \
        -d "${DB_NAME}" -c "REINDEX DATABASE ${DB_NAME};"
}

# Main maintenance routine
log_message "Starting maintenance tasks..."

# Check database size before maintenance
check_db_size

# Perform maintenance tasks based on parameters
case "${VACUUM_TYPE}" in
    "full"|"analyze")
        perform_vacuum "${VACUUM_TYPE}" "${TABLE_NAME}"
        ;;
    "reindex")
        reindex_database
        ;;
    "analyze-queries")
        analyze_queries
        ;;
    "check-all")
        check_table_sizes
        check_index_usage
        check_long_queries
        analyze_queries
        ;;
    *)
        echo "Invalid maintenance type. Use: full, analyze, reindex, analyze-queries, or check-all"
        exit 1
        ;;
esac

# Check database size after maintenance
check_db_size

log_message "Maintenance completed successfully"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Database maintenance completed. Check ${LOG_FILE} for details." | \
    mail -s "Database Maintenance Notification" ${ADMIN_EMAIL}
fi