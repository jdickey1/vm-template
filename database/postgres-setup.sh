#!/bin/bash

# PostgreSQL Setup and Configuration Script
set -e

echo "Starting PostgreSQL setup..."

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Install PostgreSQL
echo "Installing PostgreSQL..."
apt-get update
apt-get install -y postgresql postgresql-contrib

# Start PostgreSQL service
systemctl start postgresql
systemctl enable postgresql

# Create database directory if it doesn't exist
mkdir -p /var/lib/postgresql/data
chown postgres:postgres /var/lib/postgresql/data

# Configure PostgreSQL
PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

# Backup original configuration
cp "$PG_CONF" "${PG_CONF}.backup"
cp "$PG_HBA" "${PG_HBA}.backup"

# Update PostgreSQL configuration
cat > "$PG_CONF" << EOL
# DB Version: ${PG_VERSION}
# OS Type: linux
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'

# Performance tuning
work_mem = 4MB
maintenance_work_mem = 64MB
effective_cache_size = 512MB
random_page_cost = 1.1
effective_io_concurrency = 200
wal_buffers = 16MB
checkpoint_completion_target = 0.9
default_statistics_target = 100

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0

# Replication
wal_level = replica
max_wal_senders = 10
wal_keep_segments = 32
EOL

# Update pg_hba.conf
cat > "$PG_HBA" << EOL
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all            postgres                                peer
local   all            all                                     md5
host    all            all             127.0.0.1/32            md5
host    all            all             ::1/128                 md5
EOL

# Set correct permissions
chown postgres:postgres "$PG_CONF"
chown postgres:postgres "$PG_HBA"
chmod 640 "$PG_CONF"
chmod 640 "$PG_HBA"

# Create database and user
echo "Creating database and user..."
su - postgres -c "psql -c \"CREATE USER ${DB_USER:-nextjs} WITH PASSWORD '${DB_PASSWORD}';\""
su - postgres -c "psql -c \"CREATE DATABASE ${DB_NAME:-nextjs} OWNER ${DB_USER:-nextjs};\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME:-nextjs} TO ${DB_USER:-nextjs};\""

# Create extensions
su - postgres -c "psql -d ${DB_NAME:-nextjs} -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'"
su - postgres -c "psql -d ${DB_NAME:-nextjs} -c 'CREATE EXTENSION IF NOT EXISTS \"pg_stat_statements\";'"

# Restart PostgreSQL to apply changes
systemctl restart postgresql

# Create backup directory
mkdir -p /var/backups/postgresql
chown postgres:postgres /var/backups/postgresql

# Create maintenance scripts directory
mkdir -p /var/lib/postgresql/maintenance
chown postgres:postgres /var/lib/postgresql/maintenance

echo "PostgreSQL setup completed successfully!"

# Record setup in log
logger "PostgreSQL setup completed"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "PostgreSQL setup completed successfully" | \
    mail -s "PostgreSQL Setup Notification" ${ADMIN_EMAIL}
fi