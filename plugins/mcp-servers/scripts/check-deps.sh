#!/usr/bin/env bash
set -euo pipefail

# MCP Servers — Dependency Checker
# Verifies that required tools and API keys are available for each MCP server.

if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' CYAN='' NC=''
fi

# Check project-level env first, then user-level
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
if [ -f "$PROJECT_ROOT/.claude/.env" ]; then
    ENV_FILE="$PROJECT_ROOT/.claude/.env"
elif [ -f "$HOME/.claude/.env.mcp" ]; then
    ENV_FILE="$HOME/.claude/.env.mcp"
else
    ENV_FILE=""
fi

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

    # Then check env file
    if [ -z "$value" ] && [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
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

API_KEYS=(
    "PERPLEXITY_API_KEY:perplexity-ask"
    "GITHUB_TOKEN:github"
    "VERCEL_TOKEN:vercel"
    "LINEAR_API_KEY:linear"
    "NEON_API_KEY:neon"
    "SENTRY_AUTH_TOKEN:sentry"
    "BRAVE_API_KEY:brave-search"
    "NOTION_TOKEN:notion"
    "SLACK_BOT_TOKEN:slack"
    "FIGMA_TOKEN:figma"
    "MERCADOPAGO_ACCESS_TOKEN:mercadopago"
    "SUPABASE_ACCESS_TOKEN:supabase"
    "SOCKET_API_KEY:socket"
    "BROWSERSTACK_USERNAME:browserstack (username)"
    "BROWSERSTACK_ACCESS_KEY:browserstack (access key)"
    "UPSTASH_REDIS_REST_URL:redis/upstash (url)"
    "UPSTASH_REDIS_REST_TOKEN:redis/upstash (token)"
    "TWENTY_FIRST_API_KEY:@21st-dev/magic"
)
for entry in "${API_KEYS[@]}"; do
    key="${entry%%:*}"
    name="${entry#*:}"
    if check_env "$key" "$name"; then
        PASS=$((PASS + 1))
    else
        WARN=$((WARN + 1))
    fi
done
echo ""

echo -e "${CYAN}Connection Required:${NC}"
CONN_KEYS=(
    "DATABASE_URL:postgres"
    "SQLITE_DB_PATH:sqlite"
)
for entry in "${CONN_KEYS[@]}"; do
    key="${entry%%:*}"
    name="${entry#*:}"
    if check_env "$key" "$name"; then
        PASS=$((PASS + 1))
    else
        WARN=$((WARN + 1))
    fi
done
echo ""

echo -e "${CYAN}Summary:${NC}"
echo -e "  ${GREEN}${#ALWAYS[@]}${NC} servers always available (no key needed)"
echo -e "  ${GREEN}${PASS}${NC} servers configured"
echo -e "  ${YELLOW}${WARN}${NC} servers missing configuration"
echo ""

if [ $WARN -gt 0 ]; then
    echo "Configure missing API keys in your environment or Claude Code MCP settings."
fi
