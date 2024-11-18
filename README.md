# VM Template for Next.js Applications

A comprehensive virtual machine template for deploying and managing Next.js applications. This template provides standardized application setup, database management, and local maintenance tasks.

## Features

- 🚀 **Application Management**
  - Next.js deployment configuration
  - Nginx setup with optimizations
  - SSL certificate management
  - Zero-downtime deployments

- 💾 **Database Management**
  - PostgreSQL configuration
  - Local backup management
  - Performance tuning
  - Maintenance routines

- 📊 **Local Monitoring**
  - Application metrics
  - Database monitoring
  - Resource usage tracking
  - Health check endpoints

- 🔧 **Maintenance**
  - Log rotation
  - Local backups
  - Application updates
  - Database optimization

## Prerequisites

- Ubuntu 22.04 LTS VM
- Connection to VPS infrastructure
- Domain/subdomain for the application
- GitHub repository with Next.js project

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/yourusername/vm-template.git
cd vm-template
```

2. Configure environment variables:
```bash
cp app/env/.env.example .env
nano .env
```

3. Run the installation:
```bash
./install.sh
```

## Directory Structure

```
.
├── app/
│   ├── nginx/          # Nginx configuration
│   └── env/            # Environment setup
├── database/           # Database management
├── deployment/         # Deployment scripts
├── monitoring/         # Local monitoring
├── security/           # Application security
└── maintenance/        # Local maintenance
```

## Configuration

### Required Environment Variables

```env
PROJECT_NAME=           # Your project name
DOMAIN=                # Your domain name
ADMIN_EMAIL=           # Email for notifications
GITHUB_REPO=           # GitHub repository URL
DB_PASSWORD=           # PostgreSQL password
NODE_ENV=production    # Environment
```

### Optional Environment Variables

```env
SLACK_WEBHOOK_URL=     # For Slack notifications
NOTIFY_EMAIL=          # Additional notification email
PM2_INSTANCES=         # Number of PM2 instances
```

## Application Features

- Nginx configuration with best practices
- SSL certificate automation
- Static file optimization
- Security headers

## Database Management

### Features
- Automated backups
- Performance monitoring
- Regular maintenance
- Backup verification

## Local Monitoring

- Application metrics export
- Resource usage tracking
- Health check endpoints
- Error rate monitoring

## Maintenance

### Automated Tasks
- Log rotation
- Database maintenance
- Temporary file cleanup
- SSL certificate renewal

## Documentation

- [Installation Guide](docs/installation.md)
- [Application Setup](docs/application.md)
- [Database Guide](docs/database.md)
- [Maintenance Guide](docs/maintenance.md)

## Integration with VPS Infrastructure

This template is designed to work with the VPS infrastructure project:
- Reports metrics to central Prometheus
- Follows global security policies
- Integrates with central backup system
- Adheres to standardized maintenance practices

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please check:
1. Documentation in the docs/ directory
2. Open an issue on GitHub
3. Contact the system administrator
