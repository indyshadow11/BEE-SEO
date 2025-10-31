import { generateToken } from '../middleware/auth.js';
import crypto from 'crypto';

// Mock users database (replace with real database later)
const users = [
  {
    id: 'user-demo-001',
    name: 'Demo User',
    email: 'demo@bythewise.com',
    password: hashPassword('demo123'), // In production, use bcrypt
    tenantId: 'tenant-demo-001',
    role: 'admin',
    created_at: new Date().toISOString(),
  },
];

// Simple password hashing (replace with bcrypt in production)
function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

/**
 * Auth routes
 */
export default async function authRoutes(fastify, options) {
  /**
   * POST /api/auth/login
   * Login with email and password
   */
  fastify.post('/login', {
    schema: {
      body: {
        type: 'object',
        required: ['email', 'password'],
        properties: {
          email: { type: 'string', format: 'email' },
          password: { type: 'string', minLength: 1 },
        },
      },
    },
  }, async (request, reply) => {
    const { email, password } = request.body;

    // Find user
    const user = users.find((u) => u.email === email);

    if (!user) {
      return reply.code(401).send({
        error: 'Unauthorized',
        message: 'Invalid email or password',
      });
    }

    // Verify password
    const hashedPassword = hashPassword(password);
    if (user.password !== hashedPassword) {
      return reply.code(401).send({
        error: 'Unauthorized',
        message: 'Invalid email or password',
      });
    }

    // Generate JWT token
    const token = generateToken(user);

    // Return user data (without password)
    const { password: _, ...userWithoutPassword } = user;

    return {
      success: true,
      token,
      user: {
        id: userWithoutPassword.id,
        name: userWithoutPassword.name,
        email: userWithoutPassword.email,
        tenantId: userWithoutPassword.tenantId,
        role: userWithoutPassword.role,
      },
    };
  });

  /**
   * POST /api/auth/register
   * Register new user
   */
  fastify.post('/register', {
    schema: {
      body: {
        type: 'object',
        required: ['name', 'email', 'password'],
        properties: {
          name: { type: 'string', minLength: 1 },
          email: { type: 'string', format: 'email' },
          password: { type: 'string', minLength: 6 },
        },
      },
    },
  }, async (request, reply) => {
    const { name, email, password } = request.body;

    // Check if user already exists
    if (users.find((u) => u.email === email)) {
      return reply.code(400).send({
        error: 'Bad Request',
        message: 'User with this email already exists',
      });
    }

    // Create new user
    const newUser = {
      id: `user-${Date.now()}-${Math.random().toString(36).substring(7)}`,
      name,
      email,
      password: hashPassword(password),
      tenantId: `tenant-${Date.now()}-${Math.random().toString(36).substring(7)}`,
      role: 'user',
      created_at: new Date().toISOString(),
    };

    users.push(newUser);

    // Generate JWT token
    const token = generateToken(newUser);

    // Return user data (without password)
    const { password: _, ...userWithoutPassword } = newUser;

    return {
      success: true,
      token,
      user: {
        id: userWithoutPassword.id,
        name: userWithoutPassword.name,
        email: userWithoutPassword.email,
        tenantId: userWithoutPassword.tenantId,
        role: userWithoutPassword.role,
      },
    };
  });

  /**
   * GET /api/auth/me
   * Get current user
   */
  fastify.get('/me', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.user.id;

    // Find user
    const user = users.find((u) => u.id === userId);

    if (!user) {
      return reply.code(404).send({
        error: 'Not Found',
        message: 'User not found',
      });
    }

    // Return user data (without password)
    const { password: _, ...userWithoutPassword } = user;

    return {
      success: true,
      user: {
        id: userWithoutPassword.id,
        name: userWithoutPassword.name,
        email: userWithoutPassword.email,
        tenantId: userWithoutPassword.tenantId,
        role: userWithoutPassword.role,
      },
    };
  });
}
