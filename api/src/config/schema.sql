-- BYTHEWISE SaaS - Central Database Schema
-- This schema manages the multi-tenant architecture

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tenants table
CREATE TABLE IF NOT EXISTS tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  subdomain VARCHAR(100) UNIQUE NOT NULL,
  plan_tier VARCHAR(50) DEFAULT 'starter' CHECK (plan_tier IN ('starter', 'pro', 'business', 'enterprise')),
  status VARCHAR(50) DEFAULT 'provisioning' CHECK (status IN ('provisioning', 'active', 'suspended', 'deleted')),

  -- N8N Instance details
  n8n_url TEXT,
  n8n_container_id VARCHAR(100),

  -- PostgreSQL details
  postgres_container_id VARCHAR(100),
  postgres_password VARCHAR(255),

  -- Redis details
  redis_container_id VARCHAR(100),
  redis_password VARCHAR(255),

  -- Network configuration
  subnet_cidr VARCHAR(20),

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,

  -- Resource limits based on plan
  max_workflows INTEGER DEFAULT 5,
  max_executions_per_month INTEGER DEFAULT 10000,
  max_articles_per_week INTEGER DEFAULT 2
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
CREATE INDEX IF NOT EXISTS idx_tenants_plan_tier ON tenants(plan_tier);

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'user', 'viewer')),
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),

  -- Metadata
  last_login_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Workflow executions tracking
CREATE TABLE IF NOT EXISTS workflow_executions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  workflow_id VARCHAR(255) NOT NULL,
  workflow_name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'running' CHECK (status IN ('running', 'success', 'error', 'waiting')),

  -- Execution details
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  duration_ms INTEGER,

  -- Error tracking
  error_message TEXT,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflow_executions_tenant_id ON workflow_executions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_workflow_executions_status ON workflow_executions(status);
CREATE INDEX IF NOT EXISTS idx_workflow_executions_created_at ON workflow_executions(created_at);

-- Billing and usage tracking
CREATE TABLE IF NOT EXISTS billing (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  -- Usage metrics
  executions_count INTEGER DEFAULT 0,
  articles_count INTEGER DEFAULT 0,
  api_calls_count INTEGER DEFAULT 0,

  -- Billing period
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,

  -- Costs
  base_cost DECIMAL(10, 2) DEFAULT 0,
  overage_cost DECIMAL(10, 2) DEFAULT 0,
  total_cost DECIMAL(10, 2) DEFAULT 0,

  -- Status
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_billing_tenant_id ON billing(tenant_id);
CREATE INDEX IF NOT EXISTS idx_billing_period ON billing(period_start, period_end);

-- Audit logs for security
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Action details
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id UUID,

  -- Request details
  ip_address INET,
  user_agent TEXT,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_billing_updated_at BEFORE UPDATE ON billing
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to set plan limits
CREATE OR REPLACE FUNCTION set_plan_limits()
RETURNS TRIGGER AS $$
BEGIN
    CASE NEW.plan_tier
        WHEN 'starter' THEN
            NEW.max_workflows := 5;
            NEW.max_executions_per_month := 10000;
            NEW.max_articles_per_week := 2;
        WHEN 'pro' THEN
            NEW.max_workflows := 25;
            NEW.max_executions_per_month := 50000;
            NEW.max_articles_per_week := 8;
        WHEN 'business' THEN
            NEW.max_workflows := 999999;
            NEW.max_executions_per_month := 250000;
            NEW.max_articles_per_week := 20;
        WHEN 'enterprise' THEN
            NEW.max_workflows := 999999;
            NEW.max_executions_per_month := 999999;
            NEW.max_articles_per_week := 999999;
    END CASE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to set plan limits on insert/update
CREATE TRIGGER set_tenant_plan_limits
BEFORE INSERT OR UPDATE OF plan_tier ON tenants
    FOR EACH ROW EXECUTE FUNCTION set_plan_limits();
