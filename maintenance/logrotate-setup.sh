#!/bin/bash

# Log Rotation Setup Script
set -e

echo "Setting up log rotation..."

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

# Install logrotate if not installed
if ! command -v logrotate &> /dev/null; then
    apt-get update
    apt-get install -y logrotate
fi

# Create logrotate configuration directory
mkdir -p /etc/logrotate.d

# Configure Nginx logs rotation
cat > /etc/logrotate.d/nginx << EOL
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi \
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
EOL

# Configure PostgreSQL logs rotation
cat > /etc/logrotate.d/postgresql << EOL
/var/log/postgresql/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 postgres postgres
    sharedscripts
    postrotate
        /usr/lib/postgresql/*/bin/pg_ctl reload -D /var/lib/postgresql/*/main >/dev/null 2>&1
    endscript
}
EOL

# Configure application logs rotation
cat > /etc/logrotate.d/nextjs << EOL
/var/log/${PROJECT_NAME}/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    copytruncate
}
EOL

# Configure system logs rotation
cat > /etc/logrotate.d/system << EOL
/var/log/syslog
/var/log/messages
/var/log/auth.log
/var/log/user.log
/var/log/kern.log
/var/log/cron.log {
    rotate 7
    daily
    missingok
    notifempty
    delaycompress
    compress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOL

# Configure fail2ban logs rotation
cat > /etc/logrotate.d/fail2ban << EOL
/var/log/fail2ban.log {
    weekly
    rotate 4
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        fail2ban-client flushlogs >/dev/null
    endscript
}
EOL

# Create log directories if they don't exist
mkdir -p /var/log/${PROJECT_NAME}
chown www-data:adm /var/log/${PROJECT_NAME}
chmod 750 /var/log/${PROJECT_NAME}

# Test logrotate configuration
echo "Testing logrotate configuration..."
logrotate -d /etc/logrotate.conf

# Force initial rotation
logrotate -f /etc/logrotate.conf

echo "Log rotation setup completed!"

# Record setup in log
logger "Log rotation configuration updated"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Log rotation setup completed. Check /etc/logrotate.d/ for configurations." | \
    mail -s "Log Rotation Setup Notification" ${ADMIN_EMAIL}
fi