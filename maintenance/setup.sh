#!/bin/bash

# Maintenance setup script
echo "Setting up maintenance tasks..."

# Create backup directory
mkdir -p /var/backups/${PROJECT_NAME}

# Setup backup script
cat > /usr/local/bin/backup.sh << EOL
#!/bin/bash
# Database backup
pg_dump -U postgres ${PROJECT_NAME} > /var/backups/${PROJECT_NAME}/db_\$(date +%Y%m%d).sql

# Application backup
tar -czf /var/backups/${PROJECT_NAME}/app_\$(date +%Y%m%d).tar.gz /var/www/${PROJECT_NAME}

# Cleanup old backups
find /var/backups/${PROJECT_NAME} -name "db_*.sql" -mtime +7 -delete
find /var/backups/${PROJECT_NAME} -name "app_*.tar.gz" -mtime +7 -delete
EOL

chmod +x /usr/local/bin/backup.sh

# Setup cron jobs
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -

echo "Maintenance setup complete!"
