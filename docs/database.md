# Database Management Guide

This guide covers the setup, maintenance, and optimization of PostgreSQL for Next.js applications.

## Overview

The database management system includes:
- PostgreSQL setup
- Backup management
- Performance tuning
- Maintenance routines
- Monitoring integration
- Security configuration

## Database Structure

```
/var/lib/postgresql/
├── data/               # Database files
├── backups/           # Local backups
├── scripts/           # Maintenance scripts
└── logs/              # Database logs
```

## Initial Setup

### PostgreSQL Installation

```bash
# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# Initialize database cluster
pg_createcluster 14 main

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql
```

### Database Creation

```bash
# Create database and user
sudo -u postgres psql << EOF
CREATE USER ${PROJECT_NAME} WITH PASSWORD '${DB_PASSWORD}';
CREATE DATABASE ${PROJECT_NAME} OWNER ${PROJECT_NAME};
GRANT ALL PRIVILEGES ON DATABASE ${PROJECT_NAME} TO ${PROJECT_NAME};
\c ${PROJECT_NAME}
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOF
```

## Configuration

### PostgreSQL Configuration

```ini
# /etc/postgresql/14/main/postgresql.conf
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 256MB
work_mem = 4MB
maintenance_work_mem = 64MB
effective_cache_size = 768MB
wal_buffers = 16MB
checkpoint_completion_target = 0.9
random_page_cost = 1.1
effective_io_concurrency = 200
autovacuum = on
log_destination = 'csvlog'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
```

### Connection Security

```ini
# /etc/postgresql/14/main/pg_hba.conf
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

## Backup Management

### Backup Configuration

```bash
# Create backup directories
mkdir -p /var/lib/postgresql/backups/{daily,weekly,monthly}
chown -R postgres:postgres /var/lib/postgresql/backups

# Configure backup script
cat > /var/lib/postgresql/scripts/backup.sh << 'EOF'
#!/bin/bash
set -e

DB_NAME=$1
BACKUP_TYPE=$2
BACKUP_DIR="/var/lib/postgresql/backups/${BACKUP_TYPE}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup
pg_dump -Fc ${DB_NAME} > "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

# Clean old backups
find ${BACKUP_DIR} -type f -mtime +7 -delete  # Keep 7 days for daily
EOF
chmod +x /var/lib/postgresql/scripts/backup.sh
```

### Backup Schedule

```bash
# Add to crontab
cat > /etc/cron.d/postgresql-backup << EOF
# Daily backups at 1 AM
0 1 * * * postgres /var/lib/postgresql/scripts/backup.sh ${PROJECT_NAME} daily

# Weekly backups on Sunday at 2 AM
0 2 * * 0 postgres /var/lib/postgresql/scripts/backup.sh ${PROJECT_NAME} weekly

# Monthly backups on 1st at 3 AM
0 3 1 * * postgres /var/lib/postgresql/scripts/backup.sh ${PROJECT_NAME} monthly
EOF
```

## Performance Tuning

### Memory Configuration

```bash
# Calculate settings based on available memory
total_mem=$(free -m | awk '/^Mem:/{print $2}')
shared_buffers=$(($total_mem / 4))
effective_cache_size=$(($total_mem * 3 / 4))

# Update PostgreSQL configuration
sed -i "s/shared_buffers = .*/shared_buffers = ${shared_buffers}MB/" /etc/postgresql/14/main/postgresql.conf
sed -i "s/effective_cache_size = .*/effective_cache_size = ${effective_cache_size}MB/" /etc/postgresql/14/main/postgresql.conf
```

### Query Optimization

```sql
-- Enable query statistics
CREATE EXTENSION pg_stat_statements;

-- Find slow queries
SELECT 
    round((total_time/calls)::numeric, 2) as avg_time,
    calls,
    round(total_time::numeric, 2) as total_time,
    query
FROM pg_stat_statements
ORDER BY avg_time DESC
LIMIT 10;

-- Create indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_posts_user_id ON posts(user_id);
```

## Maintenance Routines

### Vacuum Configuration

```bash
# Configure autovacuum
cat >> /etc/postgresql/14/main/postgresql.conf << EOF
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.2
autovacuum_analyze_scale_factor = 0.1
autovacuum_vacuum_cost_delay = 20ms
autovacuum_vacuum_cost_limit = 200
EOF
```

### Manual Maintenance

```bash
# Create maintenance script
cat > /var/lib/postgresql/scripts/maintenance.sh << 'EOF'
#!/bin/bash
set -e

DB_NAME=$1

# Vacuum analyze
vacuumdb --analyze --verbose ${DB_NAME}

# Reindex
reindexdb --verbose ${DB_NAME}

# Update statistics
psql -d ${DB_NAME} -c "ANALYZE VERBOSE;"
EOF
chmod +x /var/lib/postgresql/scripts/maintenance.sh
```

## Monitoring Integration

### Prometheus Integration

```yaml
# /etc/prometheus/postgres_exporter.yml
pg_stat_statements:
  query: "SELECT calls, total_time, rows, query FROM pg_stat_statements"
  metrics:
    - calls:
        usage: "COUNTER"
        description: "Number of times executed"
    - total_time:
        usage: "COUNTER"
        description: "Total time spent in the statement, in milliseconds"
```

### Health Checks

```bash
# Create health check script
cat > /var/lib/postgresql/scripts/health-check.sh << 'EOF'
#!/bin/bash
set -e

DB_NAME=$1

# Check connection
psql -d ${DB_NAME} -c "SELECT 1;" > /dev/null

# Check replication lag (if applicable)
psql -d ${DB_NAME} -c "SELECT now() - pg_last_xact_replay_timestamp();"

# Check long-running queries
psql -d ${DB_NAME} -c "
SELECT pid, now() - query_start AS duration, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
AND now() - query_start > interval '5 minutes';"
EOF
chmod +x /var/lib/postgresql/scripts/health-check.sh
```

## Security Configuration

### Access Control

```sql
-- Create read-only user
CREATE ROLE readonly;
GRANT CONNECT ON DATABASE ${PROJECT_NAME} TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;

-- Create application user
CREATE ROLE app_user;
GRANT CONNECT ON DATABASE ${PROJECT_NAME} TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
```

### SSL Configuration

```bash
# Generate SSL certificate
openssl req -new -x509 -days 365 -nodes -text -out server.crt \
  -keyout server.key -subj "/CN=db.example.com"

# Configure PostgreSQL
cat >> /etc/postgresql/14/main/postgresql.conf << EOF
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
EOF
```

## Troubleshooting

### Common Issues

1. **Connection Issues**
   ```bash
   # Check logs
   tail -f /var/log/postgresql/postgresql-main.log
   
   # Check connections
   psql -c "SELECT * FROM pg_stat_activity;"
   ```

2. **Performance Issues**
   ```bash
   # Check slow queries
   psql -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
   
   # Check indexes
   psql -c "SELECT schemaname, tablename, indexname, idx_scan FROM pg_stat_user_indexes;"
   ```

3. **Space Issues**
   ```bash
   # Check database size
   psql -c "SELECT pg_size_pretty(pg_database_size('${PROJECT_NAME}'));"
   
   # Check table sizes
   psql -c "SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC;"
   ```

## Support

For database issues:
1. Check database logs
2. Review monitoring metrics
3. Contact database administrator
