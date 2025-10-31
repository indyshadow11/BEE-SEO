#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Test Provisioning Script
#
# This script tests the multi-tenant provisioning system
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  BYTHEWISE SaaS - Testing Provisioning System${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Check dependencies
echo -e "${YELLOW}Step 1: Checking dependencies...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}docker-compose is required but not installed.${NC}" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo -e "${RED}Node.js is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ All dependencies found${NC}"
echo ""

# Step 2: Ensure public network exists
echo -e "${YELLOW}Step 2: Creating Docker public network...${NC}"
docker network inspect public >/dev/null 2>&1 || docker network create public
echo -e "${GREEN}✓ Public network ready${NC}"
echo ""

# Step 3: Start PostgreSQL if not running
echo -e "${YELLOW}Step 3: Starting PostgreSQL...${NC}"
cd "$PROJECT_ROOT"
docker-compose up -d postgres
echo -e "${GREEN}✓ PostgreSQL started${NC}"
echo ""

# Step 4: Wait for PostgreSQL to be ready
echo -e "${YELLOW}Step 4: Waiting for PostgreSQL to be ready...${NC}"
sleep 5
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
echo ""

# Step 5: Initialize database
echo -e "${YELLOW}Step 5: Initializing database schema...${NC}"
cd "$PROJECT_ROOT/api"
npm install
npm run db:init
echo -e "${GREEN}✓ Database initialized${NC}"
echo ""

# Step 6: Create test tenant
echo -e "${YELLOW}Step 6: Creating test tenant...${NC}"
cd "$PROJECT_ROOT"
./scripts/create-tenant.sh "Test Client" starter
echo -e "${GREEN}✓ Test tenant created${NC}"
echo ""

# Step 7: List tenants
echo -e "${YELLOW}Step 7: Listing all tenants...${NC}"
cd "$PROJECT_ROOT/api"
npm run cli list-tenants
echo ""

# Step 8: Get tenant status
echo -e "${YELLOW}Step 8: Getting tenant status...${NC}"
TENANT_ID=$(npm run --silent cli list-tenants 2>/dev/null | grep "ID:" | head -1 | awk '{print $2}')
if [ -n "$TENANT_ID" ]; then
    npm run cli status-tenant "$TENANT_ID"
else
    echo -e "${RED}No tenant found${NC}"
fi
echo ""

# Done
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  All tests completed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Check tenant containers: docker ps | grep tenant"
echo "  2. View N8N logs: docker logs n8n-tenant-<id>"
echo "  3. Access N8N at: https://test-client.app.bythewise.com (configure DNS first)"
echo ""
