#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Full System Test Script
#
# Ce script teste l'ensemble du système avec un vrai tenant N8N
#
# Usage: ./scripts/test-full-system.sh
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Log file
LOG_FILE="/tmp/bythewise-test-$(date +%Y%m%d-%H%M%S).log"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  BYTHEWISE SaaS - Full System Test                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Log file: ${LOG_FILE}${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_step() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

log_command() {
    echo "$ $@" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1
}

check_docker() {
    print_step "Checking Docker..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo "Please start Docker and try again"
        exit 1
    fi

    print_success "Docker is running"
}

start_infrastructure() {
    print_step "Starting infrastructure (PostgreSQL + Redis)..."

    cd "$PROJECT_ROOT"

    # Start PostgreSQL
    print_info "Starting PostgreSQL..."
    docker compose up -d postgres >> "$LOG_FILE" 2>&1

    # Wait for PostgreSQL to be healthy
    print_info "Waiting for PostgreSQL to be ready..."
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if docker compose ps postgres | grep -q "healthy"; then
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
    done

    if [ $attempts -eq $max_attempts ]; then
        print_error "PostgreSQL did not become healthy in time"
        docker compose logs postgres
        exit 1
    fi

    print_success "PostgreSQL is ready"

    # Start Redis
    print_info "Starting Redis..."
    docker compose up -d redis >> "$LOG_FILE" 2>&1

    sleep 5

    if docker compose ps redis | grep -q "Up"; then
        print_success "Redis is ready"
    else
        print_error "Redis failed to start"
        docker compose logs redis
        exit 1
    fi

    # Show running containers
    echo ""
    print_info "Running containers:"
    docker compose ps
}

init_database() {
    print_step "Initializing central database..."

    cd "$PROJECT_ROOT/api"

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_info "Installing API dependencies..."
        npm install >> "$LOG_FILE" 2>&1
    fi

    # Initialize database
    print_info "Running database migrations..."
    npm run db:init

    print_success "Database initialized"

    # Verify tables
    print_info "Verifying tables..."
    docker exec bythewise-postgres psql -U admin -d bythewise_central -c "\dt" >> "$LOG_FILE" 2>&1

    echo ""
    print_success "Tables created: tenants, users, workflow_executions, billing, audit_logs"
}

create_test_tenant() {
    print_step "Creating test tenant..."

    cd "$PROJECT_ROOT"

    # Make scripts executable
    chmod +x scripts/create-tenant.sh
    chmod +x scripts/import-workflows.sh

    # Create tenant
    print_info "Provisioning tenant 'Test Client'..."

    TENANT_OUTPUT=$(./scripts/create-tenant.sh "Test Client" starter 2>&1 | tee -a "$LOG_FILE")

    # Extract tenant ID
    TENANT_ID=$(echo "$TENANT_OUTPUT" | grep "^TENANT_ID=" | cut -d= -f2)

    if [ -z "$TENANT_ID" ]; then
        print_error "Failed to extract tenant ID"
        exit 1
    fi

    print_success "Tenant created: $TENANT_ID"
    echo "$TENANT_ID" > /tmp/bythewise-test-tenant-id.txt

    # Return tenant ID
    echo "$TENANT_ID"
}

verify_tenant_containers() {
    print_step "Verifying tenant containers..."

    local tenant_id=$1

    # Get container IDs
    local n8n_container=$(docker ps -q --filter name=n8n-tenant-)
    local postgres_container=$(docker ps -q --filter name=postgres-tenant-)
    local redis_container=$(docker ps -q --filter name=redis-tenant-)

    if [ -z "$n8n_container" ]; then
        print_error "N8N container not found"
        exit 1
    fi
    print_success "N8N container running: $(docker ps --filter id=$n8n_container --format '{{.Names}}')"

    if [ -z "$postgres_container" ]; then
        print_error "PostgreSQL tenant container not found"
        exit 1
    fi
    print_success "PostgreSQL container running: $(docker ps --filter id=$postgres_container --format '{{.Names}}')"

    if [ -z "$redis_container" ]; then
        print_error "Redis tenant container not found"
        exit 1
    fi
    print_success "Redis container running: $(docker ps --filter id=$redis_container --format '{{.Names}}')"

    echo ""
    print_info "Tenant containers:"
    docker ps | grep tenant

    # Check N8N logs
    echo ""
    print_info "N8N logs (last 20 lines):"
    docker logs $(docker ps -q --filter name=n8n-tenant-) --tail 20 | tail -10
}

test_n8n_access() {
    print_step "Testing N8N access..."

    local n8n_container=$(docker ps -q --filter name=n8n-tenant-)
    local n8n_port=$(docker port $n8n_container 5678 | cut -d: -f2)

    if [ -z "$n8n_port" ]; then
        print_error "N8N port not mapped"
        exit 1
    fi

    print_info "N8N accessible on port: $n8n_port"

    # Test health endpoint
    local health_response=$(curl -s http://localhost:$n8n_port/healthz || echo "FAILED")

    if [ "$health_response" != "FAILED" ]; then
        print_success "N8N health check passed"
        print_info "N8N URL: http://localhost:$n8n_port"
    else
        print_error "N8N health check failed"
    fi
}

test_api_endpoints() {
    print_step "Testing API endpoints..."

    local tenant_id=$1

    cd "$PROJECT_ROOT/api"

    # Start API in background
    print_info "Starting API server..."
    npm run dev > /tmp/api-test.log 2>&1 &
    API_PID=$!

    # Wait for API to be ready
    sleep 5

    # Test login
    print_info "Testing login endpoint..."
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3001/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"email":"demo@bythewise.com","password":"demo123"}')

    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .token 2>/dev/null || echo "")

    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        print_error "Login failed"
        cat /tmp/api-test.log
        kill $API_PID 2>/dev/null
        exit 1
    fi

    print_success "Login successful"

    # Test /me endpoint
    print_info "Testing /me endpoint..."
    ME_RESPONSE=$(curl -s -X GET http://localhost:3001/api/auth/me \
        -H "Authorization: Bearer $TOKEN")

    if echo "$ME_RESPONSE" | jq -e .success > /dev/null 2>&1; then
        print_success "/me endpoint working"
    else
        print_error "/me endpoint failed"
    fi

    # Test metrics endpoint
    print_info "Testing metrics endpoint..."
    METRICS_RESPONSE=$(curl -s -X GET http://localhost:3001/api/tenants/tenant-demo-001/metrics \
        -H "Authorization: Bearer $TOKEN")

    if echo "$METRICS_RESPONSE" | jq -e .success > /dev/null 2>&1; then
        print_success "Metrics endpoint working"
        echo "$METRICS_RESPONSE" | jq .
    else
        print_error "Metrics endpoint failed"
    fi

    # Stop API
    kill $API_PID 2>/dev/null || true
}

show_summary() {
    local tenant_id=$1
    local n8n_port=$(docker port $(docker ps -q --filter name=n8n-tenant-) 5678 2>/dev/null | cut -d: -f2 || echo "N/A")

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ TEST COMPLETED SUCCESSFULLY                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Tenant ID: ${tenant_id}"
    print_info "N8N URL: http://localhost:${n8n_port}"
    print_info "API URL: http://localhost:3001"
    print_info "Dashboard URL: http://localhost:3000"

    echo ""
    print_info "Next steps:"
    echo "  1. Open N8N: http://localhost:${n8n_port}"
    echo "  2. Verify 3 workflows are imported (WF1, WF2, WF3)"
    echo "  3. Configure credentials in N8N (OpenAI, WordPress)"
    echo "  4. Test a workflow with sample data"

    echo ""
    print_info "Useful commands:"
    echo "  # View tenant containers"
    echo "  docker ps | grep tenant"
    echo ""
    echo "  # View N8N logs"
    echo "  docker logs $(docker ps -q --filter name=n8n-tenant-) -f"
    echo ""
    echo "  # Delete tenant"
    echo "  cd api && npm run cli delete-tenant ${tenant_id}"

    echo ""
    print_info "Log file: ${LOG_FILE}"
}

cleanup_on_error() {
    print_error "Test failed! Check log file: ${LOG_FILE}"

    # Stop any running background processes
    pkill -f "npm run dev" 2>/dev/null || true

    exit 1
}

###############################################################################
# Main Script
###############################################################################

# Setup error handler
trap cleanup_on_error ERR

print_header

# Run tests
check_docker
start_infrastructure
init_database

TENANT_ID=$(create_test_tenant)

verify_tenant_containers "$TENANT_ID"
test_n8n_access
test_api_endpoints "$TENANT_ID"

show_summary "$TENANT_ID"

print_success "All tests passed! 🎉"
echo ""
