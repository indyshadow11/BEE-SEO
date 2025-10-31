#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Tenant Provisioning Script (VERSION DEBUG)
#
# Usage: ./scripts/create-tenant-debug.sh "Client Name" [plan]
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  BYTHEWISE SaaS - Tenant Provisioning (DEBUG MODE)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
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
    echo -e "${BLUE}▶ $1${NC}"
}

print_debug() {
    echo -e "${YELLOW}[DEBUG] $1${NC}"
}

show_usage() {
    echo "Usage: $0 \"Client Name\" [plan]"
    echo ""
    echo "Arguments:"
    echo "  Client Name    The name of the client/tenant (required)"
    echo "  plan          Pricing plan: starter, pro, business, enterprise (default: starter)"
    echo ""
    echo "Examples:"
    echo "  $0 \"Test Client\" starter"
    echo "  $0 \"Acme Corp\" pro"
    echo ""
    exit 1
}

check_dependencies() {
    print_step "Checking dependencies..."

    local missing_deps=0

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        missing_deps=1
    else
        print_success "Docker found"
    fi

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        missing_deps=1
    else
        print_success "Node.js found ($(node --version))"
    fi

    # Check PostgreSQL container
    print_debug "Looking for PostgreSQL container..."
    if docker ps --format '{{.Names}}' | grep -q postgres; then
        POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep postgres | head -1)
        print_success "PostgreSQL container found: ${POSTGRES_CONTAINER}"
    else
        print_error "No PostgreSQL container running"
        missing_deps=1
    fi

    # Check Redis container
    print_debug "Looking for Redis container..."
    if docker ps --format '{{.Names}}' | grep -q redis; then
        REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep redis | head -1)
        print_success "Redis container found: ${REDIS_CONTAINER}"
    else
        print_error "No Redis container running"
        missing_deps=1
    fi

    if [ $missing_deps -eq 1 ]; then
        print_error "Missing dependencies. Please install them first."
        exit 1
    fi
}

test_database_connection() {
    print_step "Testing database connection..."

    # Load .env
    if [ -f "$PROJECT_ROOT/api/.env" ]; then
        export $(cat "$PROJECT_ROOT/api/.env" | grep -v '^#' | xargs)
        print_success ".env file loaded"
    else
        print_error ".env file not found"
        exit 1
    fi

    print_debug "POSTGRES_HOST: ${POSTGRES_HOST}"
    print_debug "POSTGRES_PORT: ${POSTGRES_PORT}"
    print_debug "POSTGRES_DB: ${POSTGRES_DB}"
    print_debug "POSTGRES_USER: ${POSTGRES_USER}"

    # Test connection with docker
    print_debug "Testing PostgreSQL connection..."
    if docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 1" > /dev/null 2>&1; then
        print_success "Database connection OK"
    else
        print_error "Cannot connect to database"
        echo ""
        echo "Trying to diagnose the issue..."

        # Check if database exists
        print_debug "Checking if database exists..."
        DB_EXISTS=$(docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -tc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" 2>/dev/null | grep -c 1 || echo "0")

        if [ "$DB_EXISTS" -eq "0" ]; then
            print_error "Database '${POSTGRES_DB}' does not exist"
            echo ""
            echo "Please run: ./scripts/diagnose-and-fix.sh"
            exit 1
        fi

        # Check tables
        print_debug "Checking if tables exist..."
        TABLES=$(docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ' || echo "0")

        if [ "$TABLES" -eq "0" ]; then
            print_error "No tables found in database"
            echo ""
            echo "Please run: ./scripts/diagnose-and-fix.sh"
            exit 1
        fi

        print_error "Unknown database issue"
        exit 1
    fi
}

validate_plan() {
    local plan=$1

    case $plan in
        starter|pro|business|enterprise)
            return 0
            ;;
        *)
            print_error "Invalid plan: $plan"
            echo "Valid plans: starter, pro, business, enterprise"
            exit 1
            ;;
    esac
}

###############################################################################
# Main Script
###############################################################################

print_header

# Check arguments
if [ -z "$1" ]; then
    print_error "Client name is required"
    echo ""
    show_usage
fi

CLIENT_NAME="$1"
PLAN="${2:-starter}"

print_info "Client Name: $CLIENT_NAME"
print_info "Plan: $PLAN"
echo ""

# Validate inputs
validate_plan "$PLAN"

# Check dependencies
check_dependencies
echo ""

# Test database connection
test_database_connection
echo ""

# Create Node.js helper script to call orchestrator
print_step "Generating tenant configuration..."

print_debug "Creating temporary Node.js script..."

cat > /tmp/create-tenant-tmp.js << EOF
import { createTenant } from '${PROJECT_ROOT}/api/src/services/orchestrator.js';
import { initDatabase, closePool } from '${PROJECT_ROOT}/api/src/config/database.js';

console.log('[DEBUG] Script started');
console.log('[DEBUG] PROJECT_ROOT:', '${PROJECT_ROOT}');

async function main() {
    try {
        console.log('[DEBUG] Initializing database...');
        await initDatabase();
        console.log('[DEBUG] Database initialized');

        console.log('[DEBUG] Creating tenant...');
        console.log('[DEBUG] Name:', '${CLIENT_NAME}');
        console.log('[DEBUG] Plan:', '${PLAN}');

        const tenant = await createTenant('${CLIENT_NAME}', '${PLAN}');

        console.log('[DEBUG] Tenant created successfully');

        console.log('\\n' + '='.repeat(60));
        console.log('TENANT CREATED SUCCESSFULLY');
        console.log('='.repeat(60));
        console.log('ID:', tenant.id);
        console.log('Name:', tenant.name);
        console.log('Subdomain:', tenant.subdomain);
        console.log('Plan:', tenant.plan);
        console.log('Status:', tenant.status);
        console.log('N8N URL:', tenant.n8n_url);
        console.log('Created:', tenant.created_at);
        console.log('='.repeat(60));
        console.log('\\nContainers:');
        console.log('  N8N:', tenant.containers.n8n);
        console.log('  PostgreSQL:', tenant.containers.postgres);
        console.log('  Redis:', tenant.containers.redis);
        console.log('='.repeat(60));

        // Output tenant ID for shell script to capture
        console.log('\\nTENANT_ID=' + tenant.id);

        await closePool();
        process.exit(0);
    } catch (error) {
        console.error('[DEBUG] Error occurred');
        console.error('Error:', error.message);
        console.error('Stack:', error.stack);
        process.exit(1);
    }
}

// Add timeout
const timeout = setTimeout(() => {
    console.error('[DEBUG] Script timeout after 60 seconds');
    process.exit(1);
}, 60000);

main().finally(() => {
    clearTimeout(timeout);
});
EOF

print_debug "Temporary script created at /tmp/create-tenant-tmp.js"
print_debug "Executing with Node.js..."

# Execute the Node.js script and capture output
cd "$PROJECT_ROOT/api"

print_debug "Working directory: $(pwd)"
print_debug "Node modules: $([ -d node_modules ] && echo 'exists' || echo 'missing')"

TENANT_OUTPUT=$(node /tmp/create-tenant-tmp.js 2>&1)
EXIT_CODE=$?

# Display the output
echo "$TENANT_OUTPUT"

# Clean up temporary file
rm -f /tmp/create-tenant-tmp.js

# Check if tenant creation was successful
if [ $EXIT_CODE -ne 0 ]; then
    print_error "Tenant creation failed!"
    echo ""
    echo "Debug information:"
    echo "- Exit code: $EXIT_CODE"
    echo "- Check that PostgreSQL is accessible"
    echo "- Check that the database is initialized"
    echo "- Run ./scripts/diagnose-and-fix.sh for more details"
    exit 1
fi

# Extract tenant ID from output
TENANT_ID=$(echo "$TENANT_OUTPUT" | grep "^TENANT_ID=" | cut -d= -f2)

if [ -z "$TENANT_ID" ]; then
    print_error "Failed to extract tenant ID"
    exit 1
fi

echo ""
print_success "Tenant provisioning completed!"
echo ""

# Import workflows automatically
print_step "Importing workflows to N8N..."
echo ""

if [ -f "$SCRIPT_DIR/import-workflows.sh" ]; then
    if "$SCRIPT_DIR/import-workflows.sh" "$TENANT_ID"; then
        print_success "Workflows imported successfully!"
    else
        print_error "Workflow import failed, but tenant was created"
        print_info "You can retry with: ./scripts/import-workflows.sh $TENANT_ID"
    fi
else
    print_error "import-workflows.sh not found"
fi

echo ""
print_info "Next steps:"
echo "  1. Access N8N at the URL shown above"
echo "  2. Configure credentials in the N8N interface (OpenAI, WordPress, etc.)"
echo "  3. Test workflows with sample data"
echo ""
