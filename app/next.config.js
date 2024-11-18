/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable React strict mode for development
  reactStrictMode: true,

  // Output standalone build
  output: 'standalone',

  // Disable x-powered-by header
  poweredByHeader: false,

  // Enable compression
  compress: true,

  // Generate ETags
  generateEtags: true,

  // Custom build directory
  distDir: '.next',

  // Asset prefix for CDN
  assetPrefix: process.env.ASSET_PREFIX,

  // Enable image optimization
  images: {
    domains: ['assets.example.com'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60,
  },

  // Server configuration
  serverRuntimeConfig: {
    // Will only be available on the server side
    dbUrl: process.env.DB_URL,
    dbPassword: process.env.DB_PASSWORD,
    jwtSecret: process.env.JWT_SECRET,
  },

  // Public runtime configuration
  publicRuntimeConfig: {
    // Will be available on both server and client
    apiUrl: process.env.API_URL,
    environment: process.env.NODE_ENV,
  },

  // HTTP headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },

  // Webpack configuration
  webpack: (config, { buildId, dev, isServer, defaultLoaders, webpack }) => {
    // Custom webpack config
    config.plugins.push(
      new webpack.DefinePlugin({
        'process.env.BUILD_ID': JSON.stringify(buildId),
      })
    );

    // Optimization for production
    if (!dev) {
      config.optimization = {
        ...config.optimization,
        minimize: true,
        splitChunks: {
          chunks: 'all',
          minSize: 20000,
          maxSize: 244000,
          minChunks: 1,
          maxAsyncRequests: 30,
          maxInitialRequests: 30,
          cacheGroups: {
            defaultVendors: {
              test: /[\\/]node_modules[\\/]/,
              priority: -10,
              reuseExistingChunk: true,
            },
            default: {
              minChunks: 2,
              priority: -20,
              reuseExistingChunk: true,
            },
          },
        },
      };
    }

    return config;
  },

  // Redirects
  async redirects() {
    return [
      {
        source: '/old-path',
        destination: '/new-path',
        permanent: true,
      },
    ];
  },

  // Rewrites
  async rewrites() {
    return {
      beforeFiles: [
        // Rewrite API calls to internal service
        {
          source: '/api/:path*',
          destination: '/api/:path*',
        },
      ],
      afterFiles: [
        // Handle dynamic routes
        {
          source: '/products/:id',
          destination: '/products/[id]',
        },
      ],
      fallback: [
        // Fallback for missing routes
        {
          source: '/:path*',
          destination: '/_404',
        },
      ],
    };
  },

  // Environment variables
  env: {
    customKey: 'customValue',
  },

  // Experimental features
  experimental: {
    // Enable server components
    serverComponents: true,
    // Enable concurrent features
    concurrentFeatures: true,
    // Enable middleware
    middleware: true,
  },

  // Telemetry
  telemetry: false,
};

module.exports = nextConfig;
