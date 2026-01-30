#!/usr/bin/env bash
set -euo pipefail

# MCP Servers — Dependency Checker
# Verifies that required tools and API keys are available for each MCP server.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ENV_FILE="$HOME/.claude/.env.mcp"

echo -e "${CYAN}MCP Server Dependency Check${NC}"
echo ""

# Check base requirements
check_command() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name (not found: $cmd)"
        return 1
    fi
}

check_env() {
    local var="$1"
    local name="$2"
    local value=""

    # Check system env first
    value="${!var:-}"

    # Then check .env.mcp file
    if [ -z "$value" ] && [ -f "$ENV_FILE" ]; then
        value=$(grep "^${var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
    fi

    if [ -n "$value" ]; then
        echo -e "  ${GREEN}✓${NC} $name ($var)"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} $name ($var not set)"
        return 1
    fi
}

echo -e "${CYAN}Base Requirements:${NC}"
check_command "node" "Node.js"
check_command "npx" "npx"
check_command "jq" "jq"
echo ""

echo -e "${CYAN}No API Key Required (always available):${NC}"
ALWAYS=(
    "sequential-thinking"
    "context7"
    "filesystem"
    "git"
    "json"
    "playwright"
    "chrome-devtools"
    "docker"
    "cloudflare-docs"
    "shadcn-ui"
    "drizzle"
    "prisma"
)
for server in "${ALWAYS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $server"
done
echo ""

echo -e "${CYAN}API Key Required:${NC}"
PASS=0
WARN=0

check_env "PERPLEXITY_API_KEY" "perplexity-ask" && ((PASS++)) || ((WARN++))
check_env "GITHUB_TOKEN" "github" && ((PASS++)) || ((WARN++))
check_env "VERCEL_TOKEN" "vercel" && ((PASS++)) || ((WARN++))
check_env "LINEAR_API_KEY" "linear" && ((PASS++)) || ((WARN++))
check_env "NEON_API_KEY" "neon" && ((PASS++)) || ((WARN++))
check_env "SENTRY_AUTH_TOKEN" "sentry" && ((PASS++)) || ((WARN++))
check_env "BRAVE_API_KEY" "brave-search" && ((PASS++)) || ((WARN++))
check_env "NOTION_TOKEN" "notion" && ((PASS++)) || ((WARN++))
check_env "SLACK_BOT_TOKEN" "slack" && ((PASS++)) || ((WARN++))
check_env "FIGMA_TOKEN" "figma" && ((PASS++)) || ((WARN++))
check_env "MERCADOPAGO_ACCESS_TOKEN" "mercadopago" && ((PASS++)) || ((WARN++))
check_env "SUPABASE_ACCESS_TOKEN" "supabase" && ((PASS++)) || ((WARN++))
check_env "SOCKET_API_KEY" "socket" && ((PASS++)) || ((WARN++))
check_env "BROWSERSTACK_USERNAME" "browserstack (username)" && ((PASS++)) || ((WARN++))
check_env "BROWSERSTACK_ACCESS_KEY" "browserstack (access key)" && ((PASS++)) || ((WARN++))
check_env "UPSTASH_REDIS_REST_URL" "redis/upstash (url)" && ((PASS++)) || ((WARN++))
check_env "UPSTASH_REDIS_REST_TOKEN" "redis/upstash (token)" && ((PASS++)) || ((WARN++))
check_env "TWENTY_FIRST_API_KEY" "@21st-dev/magic" && ((PASS++)) || ((WARN++))
echo ""

echo -e "${CYAN}Connection Required:${NC}"
check_env "DATABASE_URL" "postgres" && ((PASS++)) || ((WARN++))
check_env "SQLITE_DB_PATH" "sqlite" && ((PASS++)) || ((WARN++))
echo ""

echo -e "${CYAN}Summary:${NC}"
echo -e "  ${GREEN}${#ALWAYS[@]}${NC} servers always available (no key needed)"
echo -e "  ${GREEN}${PASS}${NC} servers configured"
echo -e "  ${YELLOW}${WARN}${NC} servers missing configuration"
echo ""

if [ $WARN -gt 0 ]; then
    echo "Run install.sh --setup-mcp to configure missing API keys."
fi
