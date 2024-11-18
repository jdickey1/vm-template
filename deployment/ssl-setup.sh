#!/bin/bash

# SSL Certificate Setup Script
set -e

echo "Starting SSL certificate setup..."

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

# Install certbot if not present
if ! command -v certbot >/dev/null 2>&1; then
    echo "Installing Certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Ensure nginx is installed
if ! command -v nginx >/dev/null 2>&1; then
    echo "Error: Nginx not installed"
    exit 1
fi

# Function to validate domain
validate_domain() {
    if [ -z "${DOMAIN}" ]; then
        echo "Error: DOMAIN not set in .env"
        exit 1
    fi
}

# Function to setup SSL certificate
setup_ssl() {
    local domain=$1
    echo "Setting up SSL certificate for ${domain}..."
    
    # Stop nginx temporarily
    systemctl stop nginx

    # Request certificate
    certbot certonly --standalone \
        --preferred-challenges http \
        --agree-tos \
        --non-interactive \
        --staple-ocsp \
        -d ${domain} \
        -m ${ADMIN_EMAIL} \
        --rsa-key-size 4096

    # Start nginx
    systemctl start nginx
}

# Function to setup auto-renewal
setup_auto_renewal() {
    echo "Setting up automatic renewal..."
    
    # Create renewal script
    cat > /etc/cron.daily/certbot-renew << EOL
#!/bin/bash
certbot renew --quiet --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
EOL
    
    chmod +x /etc/cron.daily/certbot-renew
}

# Function to setup OCSP stapling
setup_ocsp_stapling() {
    local domain=$1
    echo "Setting up OCSP Stapling..."
    
    # Create SSL parameters
    if [ ! -f /etc/nginx/dhparam.pem ]; then
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    fi
}

# Function to create SSL configuration
create_ssl_config() {
    local domain=$1
    echo "Creating SSL configuration..."
    
    # Create SSL configuration directory if it doesn't exist
    mkdir -p /etc/nginx/ssl
    
    # Create SSL configuration file
    cat > /etc/nginx/ssl/${domain}.conf << EOL
ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/${domain}/chain.pem;

# Modern SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# SSL sessions
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# HSTS
add_header Strict-Transport-Security "max-age=63072000" always;
EOL
}

# Main execution
echo "Validating domain..."
validate_domain

echo "Setting up SSL for ${DOMAIN}..."
setup_ssl ${DOMAIN}

echo "Setting up OCSP stapling..."
setup_ocsp_stapling ${DOMAIN}

echo "Creating SSL configuration..."
create_ssl_config ${DOMAIN}

echo "Setting up auto-renewal..."
setup_auto_renewal

echo "Testing Nginx configuration..."
nginx -t

echo "Restarting Nginx..."
systemctl restart nginx

echo "SSL setup completed successfully!"

# Record setup in log
logger "SSL certificate setup completed for ${DOMAIN}"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "SSL certificate setup completed for ${DOMAIN}" | \
    mail -s "SSL Setup Notification" ${ADMIN_EMAIL}
fi