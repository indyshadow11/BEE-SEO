#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Tenant Provisioning Script
#
# Usage: ./scripts/create-tenant.sh "Client Name" [plan]
#
# Arguments:
#   - Client Name: The name of the client/tenant
#   - Plan: starter, pro, business, or enterprise (default: starter)
#
# Example:
#   ./scripts/create-tenant.sh "Test Client" starter
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
    echo -e "${BLUE}  BYTHEWISE SaaS - Tenant Provisioning${NC}"
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
    echo "  $0 \"Enterprise Co\" enterprise"
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

    # Check for docker-compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed"
        missing_deps=1
    else
        print_success "docker-compose found"
    fi

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        missing_deps=1
    else
        print_success "Node.js found ($(node --version))"
    fi

    # Check if public network exists
    if ! docker network inspect public &> /dev/null; then
        print_info "Creating public network..."
        docker network create public
        print_success "Public network created"
    else
        print_success "Public network exists"
    fi

    if [ $missing_deps -eq 1 ]; then
        print_error "Missing dependencies. Please install them first."
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

# Create Node.js helper script to call orchestrator
print_step "Generating tenant configuration..."

cat > /tmp/create-tenant-tmp.js << EOF
import { createTenant } from '${PROJECT_ROOT}/api/src/services/orchestrator.js';
import { initDatabase, closePool } from '${PROJECT_ROOT}/api/src/config/database.js';

async function main() {
    try {
        console.log('Initializing database...');
        await initDatabase();

        console.log('Creating tenant...');
        const tenant = await createTenant('${CLIENT_NAME}', '${PLAN}');

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
        console.error('Error:', error.message);
        console.error(error.stack);
        process.exit(1);
    }
}

main();
EOF

# Execute the Node.js script and capture output
cd "$PROJECT_ROOT/api"
TENANT_OUTPUT=$(node /tmp/create-tenant-tmp.js 2>&1)
EXIT_CODE=$?

# Display the output
echo "$TENANT_OUTPUT"

# Clean up temporary file
rm -f /tmp/create-tenant-tmp.js

# Check if tenant creation was successful
if [ $EXIT_CODE -ne 0 ]; then
    print_error "Tenant creation failed!"
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
echo "  1. Access N8N at https://${CLIENT_NAME// /-}.app.bythewise.com (once DNS is configured)"
echo "  2. Configure credentials in the N8N interface (OpenAI, WordPress, etc.)"
echo "  3. Test workflows with sample data"
echo ""
echo "Workflow URLs:"
echo "  WF1: https://${CLIENT_NAME// /-}.app.bythewise.com/webhook/wf1-seed-expansion"
echo "  WF2: https://${CLIENT_NAME// /-}.app.bythewise.com/webhook/wf2-clustering"
echo "  WF3: Scheduled (Monday & Thursday at 8am)"
echo ""
