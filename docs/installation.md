# VM Template Installation Guide

This guide covers the installation and setup of a Next.js application VM using this template.

## Prerequisites

- Ubuntu 22.04 LTS VM with:
  - Minimum 2GB RAM
  - At least 20GB storage
  - Root access
  - Public IP or subdomain
- Access to VPS infrastructure
- Next.js application repository
- SSL certificate (Let's Encrypt)

## Step-by-Step Installation

### 1. Initial VM Setup

```bash
# Update system
apt update && apt upgrade -y

# Set timezone
timedatectl set-timezone UTC

# Install essential packages
apt install -y curl wget git unzip htop net-tools nginx
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/vm-template.git
cd vm-template
```

### 3. Configure Environment

```bash
# Copy environment template
cp app/env/.env.example .env

# Edit environment variables
nano .env
```

Required variables:
```env
PROJECT_NAME=myapp
DOMAIN=app.example.com
ADMIN_EMAIL=admin@example.com
GITHUB_REPO=github.com/username/repo
DB_PASSWORD=secure_password
NODE_ENV=production
```

### 4. Node.js Setup

```bash
# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install PM2
npm install -g pm2

# Install Yarn
npm install -g yarn
```

### 5. PostgreSQL Setup

```bash
# Run database setup
cd database
./postgres-setup.sh

# Verify installation
systemctl status postgresql
```

### 6. Nginx Configuration

```bash
# Copy Nginx configuration
cp app/nginx/nginx.conf /etc/nginx/sites-available/${PROJECT_NAME}
cp app/nginx/security-headers.conf /etc/nginx/conf.d/

# Create symlink
ln -s /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Reload Nginx
systemctl reload nginx
```

### 7. SSL Certificate

```bash
# Install Certbot
apt install -y certbot python3-certbot-nginx

# Obtain certificate
./deployment/ssl-setup.sh
```

### 8. Application Deployment

```bash
# Set up deployment directory
mkdir -p /var/www/${PROJECT_NAME}
chown -R www-data:www-data /var/www/${PROJECT_NAME}

# Initial deployment
./deployment/deploy.sh
```

### 9. Monitoring Setup

```bash
# Set up Node exporter
cd monitoring
./setup-node-exporter.sh

# Configure Prometheus metrics
./setup-app-metrics.sh
```

## Post-Installation Steps

### 1. Verify Services

Check that all services are running:
```bash
# Check Node.js application
pm2 status

# Check database
systemctl status postgresql

# Check web server
systemctl status nginx
```

### 2. Test Application

```bash
# Test HTTP
curl -I http://${DOMAIN}

# Test HTTPS
curl -I https://${DOMAIN}

# Test application health
curl https://${DOMAIN}/api/health
```

### 3. Configure Backups

```bash
# Set up database backups
cd database
./backup.sh --configure

# Verify backup configuration
./backup.sh --test
```

### 4. Configure Maintenance

```bash
# Set up maintenance tasks
cd maintenance
./setup.sh

# Test maintenance tasks
./test-maintenance.sh
```

## Security Configuration

### 1. Firewall Rules

```bash
# Allow only necessary ports
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
```

### 2. Fail2ban

```bash
# Install Fail2ban
apt install -y fail2ban

# Copy configuration
cp security/fail2ban/jail.local /etc/fail2ban/
systemctl restart fail2ban
```

### 3. Security Headers

```bash
# Verify security headers
curl -I https://${DOMAIN}
```

## Integration with VPS Infrastructure

### 1. Monitoring Integration

```bash
# Register with central Prometheus
./monitoring/register.sh

# Test metrics endpoint
curl http://localhost:9100/metrics
```

### 2. Backup Integration

```bash
# Configure backup user
./backup/setup-user.sh

# Test backup transfer
./backup/test-transfer.sh
```

### 3. Log Shipping

```bash
# Configure log shipping
./maintenance/setup-logging.sh

# Test log shipping
./maintenance/test-logging.sh
```

## Troubleshooting

### Common Issues

1. **Application Won't Start**
   ```bash
   # Check logs
   pm2 logs
   
   # Check Node.js
   node --version
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL
   systemctl status postgresql
   
   # Check logs
   tail -f /var/log/postgresql/postgresql-main.log
   ```

3. **Nginx Issues**
   ```bash
   # Check configuration
   nginx -t
   
   # Check logs
   tail -f /var/log/nginx/error.log
   ```

## Next Steps

1. Set up CI/CD pipeline
2. Configure monitoring alerts
3. Set up backup schedule
4. Configure automatic updates

## Maintenance Mode

To enable maintenance mode:
```bash
# Enable
./maintenance/enable-maintenance.sh

# Disable
./maintenance/disable-maintenance.sh
```

## Updates

Keep the system updated:
```bash
# Update application
./deployment/update.sh

# Update system
./maintenance/update-system.sh
```

## Support

If you encounter issues:
1. Check application logs
2. Review error messages
3. Contact support team
