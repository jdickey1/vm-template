#!/bin/bash
set -e

# Configuration
PROJECT_ROOT="/var/www"
NGINX_ROOT="/etc/nginx"
LOG_FILE="setup.log"

# Help message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -p, --project NAME      Project name (required)"
    echo "  -t, --type TYPE         Project type (nextjs)"
    echo "  -d, --domain DOMAIN     Domain name"
    echo "  -e, --email EMAIL       Admin email"
    echo "  --db-password PASS      Database password"
    echo "  -h, --help             Show this help message"
    exit 1
}

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -e|--email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name is required"
    usage
fi

# Set defaults
PROJECT_TYPE=${PROJECT_TYPE:-"nextjs"}
DOMAIN_NAME=${DOMAIN_NAME:-"$PROJECT_NAME.example.com"}
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@example.com"}
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 32)}

log "Starting project setup: $PROJECT_NAME"
log "Type: $PROJECT_TYPE"
log "Domain: $DOMAIN_NAME"

# Create project directories
log "Creating project directories..."
sudo mkdir -p "$PROJECT_ROOT/$PROJECT_NAME"/{current,releases,shared/{logs,public,uploads,tmp}}
sudo chown -R www-data:www-data "$PROJECT_ROOT/$PROJECT_NAME"

# Setup database
log "Setting up database..."
sudo -u postgres psql << EOF
CREATE USER $PROJECT_NAME WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $PROJECT_NAME OWNER $PROJECT_NAME;
GRANT ALL PRIVILEGES ON DATABASE $PROJECT_NAME TO $PROJECT_NAME;
\c $PROJECT_NAME
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOF

# Configure environment
log "Configuring environment..."
cat > "$PROJECT_ROOT/$PROJECT_NAME/.env" << EOL
# Application
PROJECT_NAME=$PROJECT_NAME
DOMAIN=$DOMAIN_NAME
ADMIN_EMAIL=$ADMIN_EMAIL
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$PROJECT_NAME
DB_USER=$PROJECT_NAME
DB_PASSWORD=$DB_PASSWORD

# Security
SESSION_SECRET=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)

# Monitoring
PROMETHEUS_METRICS=true
METRICS_PORT=9100
EOL

# Configure Nginx
log "Configuring Nginx..."
sudo cp nginx/nginx.conf "$NGINX_ROOT/sites-available/$PROJECT_NAME"
sudo sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" "$NGINX_ROOT/sites-available/$PROJECT_NAME"
sudo sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$NGINX_ROOT/sites-available/$PROJECT_NAME"
sudo ln -sf "$NGINX_ROOT/sites-available/$PROJECT_NAME" "$NGINX_ROOT/sites-enabled/"

# Setup SSL certificate
log "Setting up SSL certificate..."
sudo certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$ADMIN_EMAIL"

# Configure monitoring
log "Configuring monitoring..."
sudo mkdir -p /etc/prometheus/targets/apps
cat > "/etc/prometheus/targets/apps/$PROJECT_NAME.yml" << EOL
- targets:
  - 'localhost:9100'
  labels:
    project: '$PROJECT_NAME'
    type: '$PROJECT_TYPE'
EOL

# Setup Node.js
log "Setting up Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2 yarn

# Configure cron jobs
log "Setting up cron jobs..."
sudo mkdir -p /etc/cron.d
cat > "/etc/cron.d/$PROJECT_NAME" << EOL
# Daily maintenance
0 2 * * * www-data /var/www/$PROJECT_NAME/current/maintenance/daily.sh

# Weekly maintenance
0 3 * * 0 www-data /var/www/$PROJECT_NAME/current/maintenance/weekly.sh

# Monthly maintenance
0 4 1 * * www-data /var/www/$PROJECT_NAME/current/maintenance/monthly.sh
EOL

# Setup log rotation
log "Configuring log rotation..."
cat > "/etc/logrotate.d/$PROJECT_NAME" << EOL
/var/www/$PROJECT_NAME/shared/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        pm2 reloadLogs
    endscript
}
EOL

# Initial deployment
log "Performing initial deployment..."
./deployment/deploy.sh

# Start application
log "Starting application..."
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 startup script
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u www-data --hp /var/www/$PROJECT_NAME

# Final steps
log "Reloading services..."
sudo systemctl reload nginx
sudo systemctl restart prometheus

log "Setup completed successfully!"
log "Project: $PROJECT_NAME"
log "Domain: $DOMAIN_NAME"
log "Admin Email: $ADMIN_EMAIL"
log "Database Password: $DB_PASSWORD"
