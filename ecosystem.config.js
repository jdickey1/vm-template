module.exports = {
  apps: [
    {
      // Application configuration
      name: process.env.PROJECT_NAME || 'nextjs-app',
      script: 'node_modules/next/dist/bin/next',
      args: 'start',
      cwd: '/var/www/PROJECT_NAME/current',
      
      // Process configuration
      instances: 'max',
      exec_mode: 'cluster',
      watch: false,
      autorestart: true,
      max_memory_restart: '1G',
      
      // Environment variables
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      
      // Error handling
      max_restarts: 10,
      min_uptime: '5s',
      restart_delay: 4000,
      
      // Logging
      error_file: '/var/www/PROJECT_NAME/shared/logs/app.error.log',
      out_file: '/var/www/PROJECT_NAME/shared/logs/app.out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Metrics
      metrics: {
        port: 9209,
      },
      
      // Health check
      status_interval: 30,
      wait_ready: true,
      listen_timeout: 8000,
      kill_timeout: 1600,
      
      // Source maps
      source_map_support: true,
      
      // Node.js flags
      node_args: [
        '--max-old-space-size=2048',
        '--expose-gc',
      ],
    },
    
    // Worker processes
    {
      name: process.env.PROJECT_NAME + '-worker',
      script: 'worker.js',
      cwd: '/var/www/PROJECT_NAME/current',
      instances: 2,
      exec_mode: 'cluster',
      watch: false,
      autorestart: true,
      max_memory_restart: '500M',
      
      env: {
        NODE_ENV: 'production',
      },
      
      error_file: '/var/www/PROJECT_NAME/shared/logs/worker.error.log',
      out_file: '/var/www/PROJECT_NAME/shared/logs/worker.out.log',
      merge_logs: true,
    },
    
    // Cron jobs
    {
      name: process.env.PROJECT_NAME + '-cron',
      script: 'cron.js',
      cwd: '/var/www/PROJECT_NAME/current',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      autorestart: true,
      cron_restart: '0 */6 * * *',
      
      env: {
        NODE_ENV: 'production',
      },
      
      error_file: '/var/www/PROJECT_NAME/shared/logs/cron.error.log',
      out_file: '/var/www/PROJECT_NAME/shared/logs/cron.out.log',
      merge_logs: true,
    },
  ],
  
  // Deployment configuration
  deploy: {
    production: {
      user: 'deploy',
      host: ['host1', 'host2'],
      ref: 'origin/main',
      repo: process.env.GITHUB_REPO,
      path: '/var/www/PROJECT_NAME',
      'post-deploy': [
        'yarn install --frozen-lockfile',
        'yarn build',
        'pm2 reload ecosystem.config.js --env production',
      ].join(' && '),
      env: {
        NODE_ENV: 'production',
      },
    },
    
    staging: {
      user: 'deploy',
      host: 'staging-host',
      ref: 'origin/develop',
      repo: process.env.GITHUB_REPO,
      path: '/var/www/PROJECT_NAME',
      'post-deploy': [
        'yarn install --frozen-lockfile',
        'yarn build',
        'pm2 reload ecosystem.config.js --env staging',
      ].join(' && '),
      env: {
        NODE_ENV: 'staging',
      },
    },
  },
};
