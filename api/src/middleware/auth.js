import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'bythewise-secret-change-in-production';

/**
 * Verify JWT token
 */
export function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}

/**
 * Generate JWT token
 */
export function generateToken(user) {
  const payload = {
    id: user.id,
    email: user.email,
    tenantId: user.tenant_id || user.tenantId,
    role: user.role,
  };

  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

/**
 * Fastify middleware to authenticate requests
 */
export async function authenticate(request, reply) {
  try {
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.code(401).send({
        error: 'Unauthorized',
        message: 'Missing or invalid authorization header',
      });
    }

    const token = authHeader.substring(7);
    const decoded = verifyToken(token);

    if (!decoded) {
      return reply.code(401).send({
        error: 'Unauthorized',
        message: 'Invalid or expired token',
      });
    }

    // Attach user to request
    request.user = decoded;
  } catch (error) {
    return reply.code(401).send({
      error: 'Unauthorized',
      message: 'Authentication failed',
    });
  }
}

/**
 * Check if user has access to tenant
 */
export async function checkTenantAccess(request, reply) {
  const { id: tenantId } = request.params;
  const user = request.user;

  if (!user) {
    return reply.code(401).send({
      error: 'Unauthorized',
      message: 'User not authenticated',
    });
  }

  // Check if user has access to this tenant
  if (user.tenantId !== tenantId && user.role !== 'admin') {
    return reply.code(403).send({
      error: 'Forbidden',
      message: 'Access denied to this tenant',
    });
  }
}
