import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import dotenv from 'dotenv';

// Import middleware and routes
import { authenticate, checkTenantAccess } from './middleware/auth.js';
import authRoutes from './routes/auth.js';
import dashboardRoutes from './routes/dashboard.js';

dotenv.config();

const fastify = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    transport: {
      target: 'pino-pretty',
      options: {
        translateTime: 'HH:MM:ss Z',
        ignore: 'pid,hostname'
      }
    }
  }
});

// CORS Configuration - Allow dashboard on localhost:3000
await fastify.register(cors, {
  origin: [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    process.env.CORS_ORIGIN || '*'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS']
});

// Rate limiting
await fastify.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute'
});

// WebSocket support
await fastify.register(websocket);

// Decorate fastify instance with auth middleware
fastify.decorate('authenticate', authenticate);
fastify.decorate('checkTenantAccess', checkTenantAccess);

// Health check
fastify.get('/health', async (request, reply) => {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'BYTHEWISE API',
    version: '1.0.0'
  };
});

// Root endpoint
fastify.get('/', async (request, reply) => {
  return {
    name: 'BYTHEWISE SaaS API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      auth: {
        login: 'POST /api/auth/login',
        register: 'POST /api/auth/register',
        me: 'GET /api/auth/me'
      },
      tenants: {
        status: 'GET /api/tenants/:id/status',
        metrics: 'GET /api/tenants/:id/metrics',
        workflows: 'GET /api/tenants/:id/workflows',
        executions: 'GET /api/tenants/:id/executions',
        articles: 'GET /api/tenants/:id/articles'
      }
    }
  };
});

// Register routes
await fastify.register(authRoutes, { prefix: '/api/auth' });
await fastify.register(dashboardRoutes, { prefix: '/api/tenants' });

// Start server
const start = async () => {
  try {
    const port = process.env.PORT || 3001;
    const host = process.env.HOST || '0.0.0.0';

    await fastify.listen({ port, host });

    fastify.log.info(`🚀 BYTHEWISE API started on http://${host}:${port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
