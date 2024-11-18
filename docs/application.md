# Application Setup Guide

This guide covers the setup and configuration of the Next.js application environment.

## Overview

The application setup includes:
- Next.js configuration
- Environment setup
- Process management
- Static file serving
- Performance optimization
- Security configuration

## Application Structure

```
/var/www/PROJECT_NAME/
├── current/              # Current deployment
├── releases/            # Previous releases
├── shared/              # Shared assets
│   ├── uploads/
│   ├── logs/
│   └── public/
└── .env                # Environment variables
```

## Next.js Configuration

### Production Configuration

```javascript
// next.config.js
module.exports = {
  output: 'standalone',
  poweredByHeader: false,
  compress: true,
  generateEtags: true,
  
  headers: async () => [
    {
      source: '/:path*',
      headers: [
        { key: 'X-DNS-Prefetch-Control', value: 'on' },
        { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
      ],
    },
  ],
  
  webpack: (config, { isServer }) => {
    // Optimization configurations
    if (!isServer) {
      config.optimization.splitChunks.cacheGroups = {
        commons: {
          name: 'commons',
          chunks: 'all',
          minChunks: 2,
        },
      };
    }
    return config;
  },
}
```

### Environment Setup

```bash
# Application environment
cat > /var/www/${PROJECT_NAME}/.env << EOL
# Application
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${PROJECT_NAME}
DB_USER=${PROJECT_NAME}
DB_PASSWORD=${DB_PASSWORD}

# Redis (if used)
REDIS_HOST=localhost
REDIS_PORT=6379

# API Keys
API_KEY=${API_KEY}
API_SECRET=${API_SECRET}

# Security
SESSION_SECRET=${SESSION_SECRET}
JWT_SECRET=${JWT_SECRET}

# Monitoring
PROMETHEUS_METRICS=true
METRICS_PORT=9100
EOL
```

## Process Management

### PM2 Configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: process.env.PROJECT_NAME,
    script: 'node_modules/next/dist/bin/next',
    args: 'start',
    instances: 'max',
    exec_mode: 'cluster',
    autorestart: true,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
  }],
};
```

### Process Monitoring

```bash
# Monitor processes
pm2 monit

# View logs
pm2 logs

# Check status
pm2 status
```

## Static File Serving

### Nginx Configuration

```nginx
# /etc/nginx/sites-available/PROJECT_NAME
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    root /var/www/PROJECT_NAME/current/public;

    # Security headers
    include /etc/nginx/conf.d/security-headers.conf;

    # Static file serving
    location /_next/static/ {
        alias /var/www/PROJECT_NAME/current/.next/static/;
        expires 365d;
        access_log off;
    }

    location /static/ {
        alias /var/www/PROJECT_NAME/shared/public/static/;
        expires 365d;
        access_log off;
    }

    # Proxy to Next.js
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## Performance Optimization

### Application Optimization

```javascript
// pages/_app.js
import { useEffect } from 'react';
import Router from 'next/router';
import NProgress from 'nprogress';

// Route loading indicator
Router.events.on('routeChangeStart', () => NProgress.start());
Router.events.on('routeChangeComplete', () => NProgress.done());
Router.events.on('routeChangeError', () => NProgress.done());

// Performance monitoring
export function reportWebVitals(metric) {
  if (process.env.NODE_ENV === 'production') {
    // Send to monitoring service
    console.log(metric);
  }
}
```

### Cache Configuration

```javascript
// pages/api/[...slug].js
export default function handler(req, res) {
  // Cache-Control headers
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate');
  
  // Response
  res.status(200).json({ data: 'cached' });
}
```

## Security Configuration

### Content Security Policy

```javascript
// pages/_document.js
import Document, { Html, Head, Main, NextScript } from 'next/document';

class MyDocument extends Document {
  render() {
    return (
      <Html>
        <Head>
          <meta httpEquiv="Content-Security-Policy" content={`
            default-src 'self';
            script-src 'self' 'unsafe-inline' 'unsafe-eval';
            style-src 'self' 'unsafe-inline';
            img-src 'self' data: https:;
          `} />
        </Head>
        <body>
          <Main />
          <NextScript />
        </body>
      </Html>
    );
  }
}

export default MyDocument;
```

### API Rate Limiting

```javascript
// pages/api/_middleware.js
import rateLimit from 'express-rate-limit';
import { getIP } from '../../utils/request';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

export default function middleware(req, res) {
  return new Promise((resolve, reject) => {
    limiter(req, res, (result) => {
      if (result instanceof Error) {
        reject(result);
      }
      resolve(result);
    });
  });
}
```

## Monitoring Integration

### Prometheus Metrics

```javascript
// pages/api/metrics.js
import client from 'prom-client';

// Create metrics
const httpRequestDurationMicroseconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.5, 1, 5],
});

// Collect metrics
export default async function handler(req, res) {
  res.setHeader('Content-Type', client.register.contentType);
  res.send(await client.register.metrics());
}
```

## Deployment Process

### Zero-Downtime Deployment

```bash
#!/bin/bash
# deploy.sh

set -e

# Configuration
DEPLOY_DIR="/var/www/${PROJECT_NAME}"
RELEASE_DIR="${DEPLOY_DIR}/releases/$(date +%Y%m%d%H%M%S)"
CURRENT_DIR="${DEPLOY_DIR}/current"

# Clone repository
git clone ${GITHUB_REPO} ${RELEASE_DIR}

# Install dependencies
cd ${RELEASE_DIR}
yarn install --frozen-lockfile

# Build application
yarn build

# Link shared files
ln -s ${DEPLOY_DIR}/shared/uploads ${RELEASE_DIR}/public/uploads

# Switch to new release
ln -sfn ${RELEASE_DIR} ${CURRENT_DIR}

# Restart application
pm2 reload ${PROJECT_NAME}

# Clean old releases
cd ${DEPLOY_DIR}/releases
ls -t | tail -n +6 | xargs rm -rf
```

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check build logs
   tail -f /var/www/PROJECT_NAME/current/.next/build.log
   
   # Clear cache and rebuild
   rm -rf .next
   yarn build
   ```

2. **Runtime Errors**
   ```bash
   # Check application logs
   pm2 logs
   
   # Check error tracking
   tail -f /var/log/PROJECT_NAME/error.log
   ```

3. **Performance Issues**
   ```bash
   # Check resource usage
   pm2 monit
   
   # Profile application
   NODE_OPTIONS='--prof' pm2 start
   ```

## Support

For application issues:
1. Check application logs
2. Review error tracking
3. Contact development team
