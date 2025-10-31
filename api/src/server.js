import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import dotenv from 'dotenv';

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

// Plugins
await fastify.register(cors, {
  origin: process.env.CORS_ORIGIN || '*'
});

await fastify.register(jwt, {
  secret: process.env.JWT_SECRET || 'bythewise-secret-change-in-production'
});

await fastify.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute'
});

await fastify.register(websocket);

// Health check
fastify.get('/health', async (request, reply) => {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'BYTHEWISE API'
  };
});

// Root endpoint
fastify.get('/', async (request, reply) => {
  return {
    name: 'BYTHEWISE SaaS API',
    version: '1.0.0',
    docs: '/docs'
  };
});

// Routes will be added here
// await fastify.register(authRoutes, { prefix: '/api/auth' });
// await fastify.register(tenantsRoutes, { prefix: '/api/tenants' });
// await fastify.register(workflowsRoutes, { prefix: '/api/workflows' });

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
