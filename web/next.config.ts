import type { NextConfig } from 'next';
const config: NextConfig = {
  async rewrites() {
    const origin = process.env.BACKEND_ORIGIN || 'http://127.0.0.1:8000';
    return [{ source: '/api/healthz', destination: `${origin}/healthz` }, {source:'/api/test/:path*', destination:`${origin}/api/test/:path*`}, {source:'/api/web/:path*', destination:`${origin}/api/web/:path*`}];
  },
  async headers() {
    return [{ source: '/:path*', headers: [
      { key: 'Referrer-Policy', value: 'no-referrer' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'Cache-Control', value: 'no-store' }
    ] }];
  }
};
export default config;
