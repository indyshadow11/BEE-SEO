#!/usr/bin/env node

/**
 * BYTHEWISE SaaS - CLI Tool
 *
 * Commands:
 *   create-tenant <name> <plan>  - Create a new tenant
 *   delete-tenant <id>           - Delete a tenant
 *   status-tenant <id>           - Get tenant status
 *   list-tenants                 - List all tenants
 */

import { createTenant, deleteTenant, getTenantStatus, listTenants } from './services/orchestrator.js';
import { initDatabase, closePool } from './config/database.js';

const args = process.argv.slice(2);
const command = args[0];

async function main() {
  try {
    // Initialize database
    await initDatabase();

    switch (command) {
      case 'create-tenant': {
        const name = args[1];
        const plan = args[2] || 'starter';

        if (!name) {
          console.error('Usage: npm run cli create-tenant <name> <plan>');
          process.exit(1);
        }

        console.log(`Creating tenant: ${name} with plan: ${plan}`);
        const tenant = await createTenant(name, plan);

        console.log('\n' + '='.repeat(60));
        console.log('✅ TENANT CREATED SUCCESSFULLY');
        console.log('='.repeat(60));
        console.log('ID:', tenant.id);
        console.log('Name:', tenant.name);
        console.log('Subdomain:', tenant.subdomain);
        console.log('Plan:', tenant.plan);
        console.log('Status:', tenant.status);
        console.log('N8N URL:', tenant.n8n_url);
        console.log('='.repeat(60));
        break;
      }

      case 'delete-tenant': {
        const id = args[1];

        if (!id) {
          console.error('Usage: npm run cli delete-tenant <id>');
          process.exit(1);
        }

        console.log(`Deleting tenant: ${id}`);
        const result = await deleteTenant(id);

        console.log('\n✅ TENANT DELETED SUCCESSFULLY');
        console.log('ID:', result.id);
        console.log('Name:', result.name);
        console.log('Status:', result.status);
        break;
      }

      case 'status-tenant': {
        const id = args[1];

        if (!id) {
          console.error('Usage: npm run cli status-tenant <id>');
          process.exit(1);
        }

        const status = await getTenantStatus(id);

        console.log('\n' + '='.repeat(60));
        console.log('TENANT STATUS');
        console.log('='.repeat(60));
        console.log('ID:', status.id);
        console.log('Name:', status.name);
        console.log('Subdomain:', status.subdomain);
        console.log('Plan:', status.plan);
        console.log('Status:', status.status);
        console.log('N8N URL:', status.n8n_url);
        console.log('\nContainers:');
        console.log('  N8N:', status.containers.n8n);
        console.log('  PostgreSQL:', status.containers.postgres);
        console.log('  Redis:', status.containers.redis);
        console.log('\nMetrics (last 30 days):');
        console.log('  Total Executions:', status.metrics.total_executions);
        console.log('  Successful:', status.metrics.successful_executions);
        console.log('  Failed:', status.metrics.failed_executions);
        console.log('\nLimits:');
        console.log('  Max Workflows:', status.metrics.max_workflows);
        console.log('  Max Executions/Month:', status.metrics.max_executions_per_month);
        console.log('  Max Articles/Week:', status.metrics.max_articles_per_week);
        console.log('='.repeat(60));
        break;
      }

      case 'list-tenants': {
        const tenants = await listTenants();

        console.log('\n' + '='.repeat(60));
        console.log('TENANTS LIST');
        console.log('='.repeat(60));

        if (tenants.length === 0) {
          console.log('No tenants found');
        } else {
          tenants.forEach((tenant, index) => {
            console.log(`\n${index + 1}. ${tenant.name}`);
            console.log('   ID:', tenant.id);
            console.log('   Subdomain:', tenant.subdomain);
            console.log('   Plan:', tenant.plan);
            console.log('   Status:', tenant.status);
            console.log('   Created:', tenant.created_at);
          });
        }
        console.log('='.repeat(60));
        break;
      }

      default:
        console.log('BYTHEWISE SaaS - CLI Tool\n');
        console.log('Commands:');
        console.log('  create-tenant <name> <plan>  - Create a new tenant');
        console.log('  delete-tenant <id>           - Delete a tenant');
        console.log('  status-tenant <id>           - Get tenant status');
        console.log('  list-tenants                 - List all tenants');
        console.log('\nExamples:');
        console.log('  npm run cli create-tenant "Test Client" starter');
        console.log('  npm run cli list-tenants');
        console.log('  npm run cli status-tenant <tenant-id>');
        console.log('  npm run cli delete-tenant <tenant-id>');
        process.exit(1);
    }

    await closePool();
    process.exit(0);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (process.env.NODE_ENV === 'development') {
      console.error(error.stack);
    }
    await closePool();
    process.exit(1);
  }
}

main();
