import { query, getClient } from '../config/database.js';
import { randomBytes } from 'crypto';
import { exec } from 'child_process';
import { promisify } from 'util';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const execAsync = promisify(exec);

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Plan configurations
const PLAN_CONFIGS = {
  starter: {
    max_workflows: 5,
    max_executions_per_month: 10000,
    max_articles_per_week: 2,
    price: 49
  },
  pro: {
    max_workflows: 25,
    max_executions_per_month: 50000,
    max_articles_per_week: 8,
    price: 149
  },
  business: {
    max_workflows: 999999,
    max_executions_per_month: 250000,
    max_articles_per_week: 20,
    price: 499
  },
  enterprise: {
    max_workflows: 999999,
    max_executions_per_month: 999999,
    max_articles_per_week: 999999,
    price: 999
  }
};

// Generate secure password
function generatePassword(length = 32) {
  return randomBytes(length).toString('base64').slice(0, length);
}

// Generate subdomain from name
function generateSubdomain(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .substring(0, 50);
}

// Get next available subnet
async function getNextAvailableSubnet() {
  const result = await query(
    `SELECT subnet_cidr FROM tenants WHERE subnet_cidr IS NOT NULL ORDER BY created_at DESC LIMIT 1`
  );

  if (result.rows.length === 0) {
    return '172.100.0.0/24';
  }

  const lastSubnet = result.rows[0].subnet_cidr;
  const match = lastSubnet.match(/172\.(\d+)\.0\.0\/24/);

  if (!match) {
    return '172.100.0.0/24';
  }

  const nextOctet = parseInt(match[1]) + 1;
  return `172.${nextOctet}.0.0/24`;
}

// Wait for N8N instance to be ready
async function waitForN8N(containerId, maxAttempts = 30) {
  console.log(`Waiting for N8N container ${containerId} to be ready...`);

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      // Check if container is running
      const { stdout: status } = await execAsync(
        `docker inspect --format='{{.State.Status}}' ${containerId}`
      );

      if (status.trim() !== 'running') {
        console.log(`Attempt ${attempt}/${maxAttempts}: Container not running yet (${status.trim()})`);
        await new Promise(resolve => setTimeout(resolve, 2000));
        continue;
      }

      // Check if N8N health endpoint responds
      try {
        await execAsync(
          `docker exec ${containerId} wget --no-verbose --tries=1 --spider http://localhost:5678/healthz`
        );
        console.log(`✓ N8N is ready after ${attempt} attempts`);
        return true;
      } catch (error) {
        console.log(`Attempt ${attempt}/${maxAttempts}: N8N health check failed`);
      }

    } catch (error) {
      console.log(`Attempt ${attempt}/${maxAttempts}: Error checking N8N - ${error.message}`);
    }

    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  throw new Error(`N8N failed to become ready after ${maxAttempts} attempts`);
}

/**
 * Create a new tenant with isolated N8N instance
 * @param {string} name - Tenant name
 * @param {string} plan - Plan tier (starter/pro/business/enterprise)
 * @returns {Promise<Object>} - Created tenant information
 */
export async function createTenant(name, plan = 'starter') {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Validate plan
    if (!PLAN_CONFIGS[plan]) {
      throw new Error(`Invalid plan: ${plan}. Must be one of: ${Object.keys(PLAN_CONFIGS).join(', ')}`);
    }

    // Generate tenant details
    const subdomain = generateSubdomain(name);
    const postgresPassword = generatePassword();
    const redisPassword = generatePassword();
    const subnetCidr = await getNextAvailableSubnet();

    // Check if subdomain already exists
    const existing = await client.query(
      'SELECT id FROM tenants WHERE subdomain = $1',
      [subdomain]
    );

    if (existing.rows.length > 0) {
      throw new Error(`Subdomain ${subdomain} already exists`);
    }

    // Insert tenant into database
    const insertResult = await client.query(
      `INSERT INTO tenants (
        name,
        subdomain,
        plan_tier,
        status,
        postgres_password,
        redis_password,
        subnet_cidr,
        n8n_url
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
      [
        name,
        subdomain,
        plan,
        'provisioning',
        postgresPassword,
        redisPassword,
        subnetCidr,
        `https://${subdomain}.app.bythewise.com`
      ]
    );

    const tenant = insertResult.rows[0];

    // Generate docker-compose file from template
    const templatePath = join(__dirname, '../../../docker/compose/tenant-template.yml');
    const template = readFileSync(templatePath, 'utf8');

    const dockerCompose = template
      .replace(/TENANT_ID/g, tenant.id)
      .replace(/TENANT_NAME/g, name)
      .replace(/TENANT_PLAN/g, plan)
      .replace(/SUBDOMAIN/g, subdomain)
      .replace(/\{\{POSTGRES_PASSWORD\}\}/g, postgresPassword)
      .replace(/\{\{REDIS_PASSWORD\}\}/g, redisPassword)
      .replace(/SUBNET_CIDR/g, subnetCidr);

    // Save docker-compose file
    const composeFilePath = join(__dirname, `../../../docker/tenants/docker-compose-tenant-${tenant.id}.yml`);

    // Create directory if it doesn't exist
    const tenantsDir = dirname(composeFilePath);
    mkdirSync(tenantsDir, { recursive: true });

    writeFileSync(composeFilePath, dockerCompose);

    console.log(`✓ Docker compose file created: ${composeFilePath}`);

    // Create Docker network
    try {
      await execAsync(`docker network create tenant_${tenant.id} --subnet=${subnetCidr} --internal`);
      console.log(`✓ Docker network created: tenant_${tenant.id}`);
    } catch (error) {
      // Network might already exist, ignore error
      console.log(`Network tenant_${tenant.id} might already exist`);
    }

    // Start containers
    console.log(`🚀 Starting containers for tenant ${tenant.id}...`);
    const { stdout, stderr } = await execAsync(
      `docker compose -f ${composeFilePath} up -d`,
      { cwd: join(__dirname, '../..') }
    );

    if (stderr && !stderr.includes('Creating') && !stderr.includes('Starting')) {
      console.error('Docker compose stderr:', stderr);
    }

    console.log('Docker compose output:', stdout);

    // Get container IDs
    const n8nContainerId = await execAsync(
      `docker ps -q -f name=n8n-tenant-${tenant.id}`
    ).then(res => res.stdout.trim());

    const postgresContainerId = await execAsync(
      `docker ps -q -f name=postgres-tenant-${tenant.id}`
    ).then(res => res.stdout.trim());

    const redisContainerId = await execAsync(
      `docker ps -q -f name=redis-tenant-${tenant.id}`
    ).then(res => res.stdout.trim());

    // Wait for N8N to be ready
    if (n8nContainerId) {
      try {
        await waitForN8N(n8nContainerId);
      } catch (error) {
        console.error('Warning: N8N health check failed, but continuing:', error.message);
        // Don't fail the entire tenant creation if N8N is slow to start
      }
    }

    // Update tenant with container IDs
    await client.query(
      `UPDATE tenants SET
        n8n_container_id = $1,
        postgres_container_id = $2,
        redis_container_id = $3,
        status = $4,
        updated_at = NOW()
      WHERE id = $5`,
      [n8nContainerId, postgresContainerId, redisContainerId, 'active', tenant.id]
    );

    await client.query('COMMIT');

    console.log(`✅ Tenant created successfully: ${tenant.id}`);

    return {
      id: tenant.id,
      name: tenant.name,
      subdomain: tenant.subdomain,
      plan: tenant.plan_tier,
      status: 'active',
      n8n_url: tenant.n8n_url,
      created_at: tenant.created_at,
      containers: {
        n8n: n8nContainerId,
        postgres: postgresContainerId,
        redis: redisContainerId
      }
    };

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creating tenant:', error);
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Delete a tenant and all associated resources
 * @param {string} tenantId - Tenant UUID
 * @returns {Promise<Object>} - Deletion confirmation
 */
export async function deleteTenant(tenantId) {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Get tenant details
    const result = await client.query(
      'SELECT * FROM tenants WHERE id = $1',
      [tenantId]
    );

    if (result.rows.length === 0) {
      throw new Error(`Tenant ${tenantId} not found`);
    }

    const tenant = result.rows[0];

    // Stop and remove containers
    const composeFilePath = join(__dirname, `../../../docker/tenants/docker-compose-tenant-${tenantId}.yml`);

    try {
      console.log(`🛑 Stopping containers for tenant ${tenantId}...`);
      await execAsync(`docker compose -f ${composeFilePath} down -v`);
      console.log(`✓ Containers stopped and removed`);
    } catch (error) {
      console.error('Error stopping containers:', error.message);
    }

    // Remove Docker network
    try {
      await execAsync(`docker network rm tenant_${tenantId}`);
      console.log(`✓ Docker network removed`);
    } catch (error) {
      console.error('Error removing network:', error.message);
    }

    // Soft delete tenant in database
    await client.query(
      `UPDATE tenants SET
        status = $1,
        deleted_at = NOW(),
        updated_at = NOW()
      WHERE id = $2`,
      ['deleted', tenantId]
    );

    await client.query('COMMIT');

    console.log(`✅ Tenant deleted successfully: ${tenantId}`);

    return {
      id: tenantId,
      name: tenant.name,
      status: 'deleted',
      deleted_at: new Date()
    };

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error deleting tenant:', error);
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Get tenant status and metrics
 * @param {string} tenantId - Tenant UUID
 * @returns {Promise<Object>} - Tenant status information
 */
export async function getTenantStatus(tenantId) {
  try {
    // Get tenant from database
    const result = await query(
      `SELECT
        t.*,
        COUNT(DISTINCT we.id) as total_executions,
        COUNT(DISTINCT CASE WHEN we.status = 'success' THEN we.id END) as successful_executions,
        COUNT(DISTINCT CASE WHEN we.status = 'error' THEN we.id END) as failed_executions
      FROM tenants t
      LEFT JOIN workflow_executions we ON t.id = we.tenant_id
        AND we.created_at >= NOW() - INTERVAL '30 days'
      WHERE t.id = $1
      GROUP BY t.id`,
      [tenantId]
    );

    if (result.rows.length === 0) {
      throw new Error(`Tenant ${tenantId} not found`);
    }

    const tenant = result.rows[0];

    // Check container health
    const containerStatuses = {};

    if (tenant.n8n_container_id) {
      try {
        const { stdout } = await execAsync(
          `docker inspect --format='{{.State.Status}}' ${tenant.n8n_container_id}`
        );
        containerStatuses.n8n = stdout.trim();
      } catch (error) {
        containerStatuses.n8n = 'not_found';
      }
    }

    if (tenant.postgres_container_id) {
      try {
        const { stdout } = await execAsync(
          `docker inspect --format='{{.State.Status}}' ${tenant.postgres_container_id}`
        );
        containerStatuses.postgres = stdout.trim();
      } catch (error) {
        containerStatuses.postgres = 'not_found';
      }
    }

    if (tenant.redis_container_id) {
      try {
        const { stdout } = await execAsync(
          `docker inspect --format='{{.State.Status}}' ${tenant.redis_container_id}`
        );
        containerStatuses.redis = stdout.trim();
      } catch (error) {
        containerStatuses.redis = 'not_found';
      }
    }

    return {
      id: tenant.id,
      name: tenant.name,
      subdomain: tenant.subdomain,
      plan: tenant.plan_tier,
      status: tenant.status,
      n8n_url: tenant.n8n_url,
      containers: containerStatuses,
      metrics: {
        total_executions: parseInt(tenant.total_executions) || 0,
        successful_executions: parseInt(tenant.successful_executions) || 0,
        failed_executions: parseInt(tenant.failed_executions) || 0,
        max_workflows: tenant.max_workflows,
        max_executions_per_month: tenant.max_executions_per_month,
        max_articles_per_week: tenant.max_articles_per_week
      },
      created_at: tenant.created_at,
      updated_at: tenant.updated_at
    };

  } catch (error) {
    console.error('Error getting tenant status:', error);
    throw error;
  }
}

/**
 * List all tenants
 * @param {Object} filters - Optional filters (status, plan)
 * @returns {Promise<Array>} - List of tenants
 */
export async function listTenants(filters = {}) {
  try {
    let queryText = 'SELECT * FROM tenants WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (filters.status) {
      queryText += ` AND status = $${paramCount}`;
      params.push(filters.status);
      paramCount++;
    }

    if (filters.plan) {
      queryText += ` AND plan_tier = $${paramCount}`;
      params.push(filters.plan);
      paramCount++;
    }

    queryText += ' ORDER BY created_at DESC';

    const result = await query(queryText, params);

    return result.rows.map(tenant => ({
      id: tenant.id,
      name: tenant.name,
      subdomain: tenant.subdomain,
      plan: tenant.plan_tier,
      status: tenant.status,
      n8n_url: tenant.n8n_url,
      created_at: tenant.created_at
    }));

  } catch (error) {
    console.error('Error listing tenants:', error);
    throw error;
  }
}

export default {
  createTenant,
  deleteTenant,
  getTenantStatus,
  listTenants
};
