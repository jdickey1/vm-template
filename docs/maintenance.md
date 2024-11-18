# VM Maintenance Guide

This guide covers the maintenance procedures for individual VM instances running Next.js applications.

## Overview

The maintenance system manages:
- Application updates
- Database maintenance
- Log management
- Backup verification
- Performance monitoring
- Security updates

## Maintenance Schedule

### Daily Tasks
- Application health checks
- Log rotation
- Database backups
- Performance monitoring

### Weekly Tasks
- Security updates
- Database maintenance
- Backup verification
- SSL certificate checks

### Monthly Tasks
- Full system updates
- Performance optimization
- Security audits
- Storage cleanup

## Application Maintenance

### Process Management

```bash
# Check application status
pm2 status

# Monitor resources
pm2 monit

# Rotate logs
pm2 flush
pm2 reloadLogs
```

### Application Updates

```bash
# Update application
cd /var/www/${PROJECT_NAME}
./deployment/update.sh

# Verify deployment
./deployment/verify-deployment.sh

# Rollback if needed
./deployment/rollback.sh
```

### Cache Management

```bash
# Clear application cache
cd /var/www/${PROJECT_NAME}/current
yarn cache clean

# Clear build cache
rm -rf .next/cache

# Clear CDN cache (if applicable)
./scripts/clear-cdn-cache.sh
```

## Database Maintenance

### Regular Maintenance

```bash
# Run vacuum
cd /var/lib/postgresql/scripts
./maintenance.sh ${PROJECT_NAME}

# Update statistics
psql -d ${PROJECT_NAME} -c "ANALYZE VERBOSE;"

# Check indexes
psql -d ${PROJECT_NAME} -c "
SELECT schemaname, tablename, indexname, idx_scan 
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;"
```

### Backup Verification

```bash
# List backups
cd /var/lib/postgresql/backups
ls -lah

# Verify latest backup
./verify-backup.sh ${PROJECT_NAME}

# Test restore
./test-restore.sh ${PROJECT_NAME}
```

## Log Management

### Log Rotation

```bash
# Configure log rotation
cat > /etc/logrotate.d/nextjs << EOF
/var/www/${PROJECT_NAME}/shared/logs/*.log {
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
EOF
```

### Log Analysis

```bash
# Check error rates
./scripts/analyze-logs.sh --type=error

# Generate access report
./scripts/analyze-logs.sh --type=access

# Check resource usage
./scripts/analyze-logs.sh --type=resource
```

## Performance Monitoring

### System Resources

```bash
# Check system resources
./monitoring/check-resources.sh

# Monitor network
./monitoring/check-network.sh

# Check disk usage
./monitoring/check-disk.sh
```

### Application Performance

```bash
# Check response times
./monitoring/check-response.sh

# Monitor memory usage
./monitoring/check-memory.sh

# Generate performance report
./monitoring/generate-report.sh
```

## Security Maintenance

### Security Updates

```bash
# Update security packages
apt update
apt upgrade -y

# Check security advisories
./security/check-advisories.sh

# Apply security patches
./security/apply-patches.sh
```

### SSL Certificates

```bash
# Check certificate expiry
./security/check-ssl.sh

# Renew certificates
./security/renew-ssl.sh

# Verify SSL configuration
./security/verify-ssl.sh
```

## Storage Management

### Cleanup Tasks

```bash
# Clean old releases
cd /var/www/${PROJECT_NAME}/releases
ls -t | tail -n +6 | xargs rm -rf

# Clean temporary files
find /tmp -type f -atime +7 -delete

# Clean npm cache
npm cache clean --force
```

### Disk Space Management

```bash
# Check disk usage
df -h

# Find large files
find /var/www/${PROJECT_NAME} -type f -size +100M

# Clean old logs
find /var/log -name "*.gz" -mtime +30 -delete
```

## Integration Maintenance

### VPS Infrastructure Integration

```bash
# Update monitoring configuration
./monitoring/update-config.sh

# Verify backup integration
./backup/verify-integration.sh

# Test log shipping
./logging/test-shipping.sh
```

### Service Dependencies

```bash
# Check external services
./monitoring/check-external.sh

# Verify API integrations
./monitoring/check-apis.sh

# Test CDN configuration
./monitoring/check-cdn.sh
```

## Automation

### Maintenance Scripts

```bash
# Create maintenance wrapper
cat > /usr/local/bin/vm-maintenance << 'EOF'
#!/bin/bash
set -e

case "$1" in
    daily)
        ./maintenance/daily.sh
        ;;
    weekly)
        ./maintenance/weekly.sh
        ;;
    monthly)
        ./maintenance/monthly.sh
        ;;
    *)
        echo "Usage: $0 {daily|weekly|monthly}"
        exit 1
        ;;
esac
EOF
chmod +x /usr/local/bin/vm-maintenance
```

### Scheduled Tasks

```bash
# Configure maintenance schedule
cat > /etc/cron.d/vm-maintenance << EOF
# Daily maintenance at 2 AM
0 2 * * * root /usr/local/bin/vm-maintenance daily

# Weekly maintenance on Sunday at 3 AM
0 3 * * 0 root /usr/local/bin/vm-maintenance weekly

# Monthly maintenance on 1st at 4 AM
0 4 1 * * root /usr/local/bin/vm-maintenance monthly
EOF
```

## Troubleshooting

### Common Issues

1. **Application Issues**
   ```bash
   # Check application logs
   pm2 logs
   
   # Check error logs
   tail -f /var/www/${PROJECT_NAME}/shared/logs/error.log
   
   # Check system logs
   journalctl -u pm2-${PROJECT_NAME}
   ```

2. **Database Issues**
   ```bash
   # Check database logs
   tail -f /var/log/postgresql/postgresql-main.log
   
   # Check connections
   psql -c "SELECT * FROM pg_stat_activity;"
   ```

3. **Performance Issues**
   ```bash
   # Check load average
   uptime
   
   # Check memory usage
   free -h
   
   # Check disk I/O
   iostat -x 1
   ```

## Reporting

### System Reports

```bash
# Generate system report
./maintenance/generate-report.sh --type=system

# Generate performance report
./maintenance/generate-report.sh --type=performance

# Generate security report
./maintenance/generate-report.sh --type=security
```

### Maintenance Reports

```bash
# Generate maintenance summary
./maintenance/generate-summary.sh

# Check maintenance history
./maintenance/show-history.sh

# Generate detailed report
./maintenance/generate-report.sh --detailed
```

## Support

For maintenance issues:
1. Check application logs
2. Review system status
3. Contact support team
