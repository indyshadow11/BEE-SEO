#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Import Workflows to N8N Instance
#
# Usage: ./scripts/import-workflows.sh <tenant_id> [n8n_url]
#
# Arguments:
#   - tenant_id: UUID of the tenant
#   - n8n_url: (optional) N8N instance URL, will be fetched from DB if not provided
#
# Example:
#   ./scripts/import-workflows.sh "abc-123-def"
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
WORKFLOWS_DIR="$PROJECT_ROOT/workflows/export"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  BYTHEWISE - Import Workflows to N8N${NC}"
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

wait_for_n8n() {
    local n8n_url=$1
    local max_attempts=30
    local attempt=1

    print_step "Waiting for N8N to be ready at $n8n_url..."

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "${n8n_url}/healthz" > /dev/null 2>&1; then
            print_success "N8N is ready!"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "N8N failed to start after ${max_attempts} attempts"
    return 1
}

import_workflow() {
    local workflow_file=$1
    local n8n_url=$2
    local subdomain=$3
    local workflow_name=$(basename "$workflow_file" .json)

    print_step "Importing $workflow_name..."

    # Read workflow JSON
    local workflow_json=$(cat "$workflow_file")

    # Replace placeholder subdomain with actual subdomain
    workflow_json=$(echo "$workflow_json" | sed "s/SUBDOMAIN_PLACEHOLDER/${subdomain}/g")

    # Import workflow via N8N API
    local response=$(curl -sf -X POST \
        "${n8n_url}/api/v1/workflows" \
        -H "Content-Type: application/json" \
        -d "$workflow_json" 2>&1)

    if [ $? -eq 0 ]; then
        local workflow_id=$(echo "$response" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
        print_success "Imported $workflow_name (ID: $workflow_id)"

        # Extract webhook path if it's a webhook workflow
        if echo "$workflow_json" | grep -q "webhook"; then
            local webhook_path=$(echo "$workflow_json" | grep -o '"path":"[^"]*' | head -1 | cut -d'"' -f4)
            if [ -n "$webhook_path" ]; then
                echo -e "  ${YELLOW}Webhook URL: ${n8n_url}/webhook/${webhook_path}${NC}"
            fi
        fi

        return 0
    else
        print_error "Failed to import $workflow_name"
        echo "$response"
        return 1
    fi
}

activate_workflow() {
    local workflow_id=$1
    local n8n_url=$2

    print_step "Activating workflow $workflow_id..."

    local response=$(curl -sf -X PATCH \
        "${n8n_url}/api/v1/workflows/${workflow_id}" \
        -H "Content-Type: application/json" \
        -d '{"active": true}' 2>&1)

    if [ $? -eq 0 ]; then
        print_success "Workflow activated"
        return 0
    else
        print_error "Failed to activate workflow"
        return 1
    fi
}

###############################################################################
# Main Script
###############################################################################

print_header

# Check arguments
if [ -z "$1" ]; then
    print_error "Tenant ID is required"
    echo ""
    echo "Usage: $0 <tenant_id> [n8n_url]"
    echo ""
    echo "Example:"
    echo "  $0 abc-123-def"
    echo "  $0 abc-123-def http://localhost:5678"
    exit 1
fi

TENANT_ID="$1"
N8N_URL="$2"

print_info "Tenant ID: $TENANT_ID"

# If N8N URL not provided, fetch from database
if [ -z "$N8N_URL" ]; then
    print_step "Fetching N8N URL from database..."

    # Get tenant info from database using Node.js
    TENANT_INFO=$(cd "$PROJECT_ROOT/api" && node -e "
        import('./src/config/database.js').then(async (db) => {
            const result = await db.query('SELECT subdomain, n8n_container_id FROM tenants WHERE id = \$1', ['${TENANT_ID}']);
            if (result.rows.length > 0) {
                const subdomain = result.rows[0].subdomain;
                const containerId = result.rows[0].n8n_container_id;

                // Try to get container port
                let port = 5678;
                try {
                    const { execSync } = require('child_process');
                    const portInfo = execSync(\`docker port n8n-tenant-${TENANT_ID} 5678\`).toString().trim();
                    if (portInfo) {
                        port = portInfo.split(':')[1];
                    }
                } catch (e) {
                    // Use default port
                }

                console.log(JSON.stringify({ subdomain, port }));
            }
            await db.closePool();
            process.exit(0);
        });
    " 2>/dev/null)

    if [ -n "$TENANT_INFO" ]; then
        SUBDOMAIN=$(echo "$TENANT_INFO" | grep -o '"subdomain":"[^"]*' | cut -d'"' -f4)
        PORT=$(echo "$TENANT_INFO" | grep -o '"port":"[^"]*' | cut -d'"' -f4)
        PORT=${PORT:-5678}

        # For local development, use localhost
        N8N_URL="http://localhost:${PORT}"

        print_success "Found tenant: $SUBDOMAIN"
        print_info "N8N URL: $N8N_URL"
    else
        print_error "Tenant not found in database"
        exit 1
    fi
else
    # Extract subdomain from N8N_URL or use tenant_id
    SUBDOMAIN=$(echo "$N8N_URL" | sed -E 's|https?://([^.]+).*|\1|')
fi

echo ""

# Wait for N8N to be ready
wait_for_n8n "$N8N_URL"
echo ""

# Import workflows
print_step "Importing workflows..."
echo ""

WORKFLOWS=(
    "WF1_seed_expansion.json"
    "WF2_clustering.json"
    "WF3_generation.json"
)

IMPORTED_COUNT=0
FAILED_COUNT=0

for workflow_file in "${WORKFLOWS[@]}"; do
    WORKFLOW_PATH="$WORKFLOWS_DIR/$workflow_file"

    if [ ! -f "$WORKFLOW_PATH" ]; then
        print_error "Workflow file not found: $WORKFLOW_PATH"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    if import_workflow "$WORKFLOW_PATH" "$N8N_URL" "$SUBDOMAIN"; then
        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    echo ""
done

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}IMPORT SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "Total workflows: ${#WORKFLOWS[@]}"
echo -e "Imported: ${GREEN}$IMPORTED_COUNT${NC}"
echo -e "Failed: ${RED}$FAILED_COUNT${NC}"
echo ""

if [ $IMPORTED_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ Workflows imported successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Access N8N: $N8N_URL"
    echo "  2. Configure credentials (OpenAI, WordPress, etc.)"
    echo "  3. Test workflows with sample data"
    echo ""
    echo "Webhook URLs:"
    echo "  WF1: ${N8N_URL}/webhook/wf1-seed-expansion"
    echo "  WF2: ${N8N_URL}/webhook/wf2-clustering"
    echo "  WF3: Scheduled (Mon & Thu 8am)"
    echo ""
fi

exit $FAILED_COUNT
