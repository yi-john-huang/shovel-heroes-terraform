#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔒 RDS Database Tunnel Setup${NC}"
echo ""

# Check if terraform outputs exist
if ! terraform output -raw bastion_ssm_instance_id &>/dev/null; then
    echo -e "${RED}Error: bastion_ssm_instance_id output not found${NC}"
    echo "Make sure terraform has been applied and bastion host is created"
    exit 1
fi

# Get terraform outputs
BASTION_ID=$(terraform output -raw bastion_ssm_instance_id)
RDS_ENDPOINT=$(terraform output -raw rds_address)
DB_NAME=$(terraform output -raw rds_database_name)
DB_SECRET_ARN=$(terraform output -raw database_secret_arn)

echo -e "${YELLOW}Bastion Instance:${NC} $BASTION_ID"
echo -e "${YELLOW}RDS Endpoint:${NC} $RDS_ENDPOINT"
echo ""

# Get database credentials
echo -e "${GREEN}📋 Fetching database credentials...${NC}"
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "$DB_SECRET_ARN" \
    --region ap-east-2 \
    --query SecretString \
    --output text | jq -r '.password')

if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" == "null" ]; then
    echo -e "${RED}Error: Failed to retrieve database password${NC}"
    echo -e "${YELLOW}Tip: Check if the secret exists in ap-east-2 region${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Credentials retrieved${NC}"
echo ""

# Display connection info
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 pgAdmin Connection Details${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Host:${NC}     localhost"
echo -e "${YELLOW}Port:${NC}     5433"
echo -e "${YELLOW}Database:${NC} $DB_NAME"
echo -e "${YELLOW}Username:${NC} dbadmin"
echo -e "${YELLOW}Password:${NC} $DB_PASSWORD"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Copy password to clipboard if available
if command -v pbcopy &> /dev/null; then
    echo "$DB_PASSWORD" | pbcopy
    echo -e "${GREEN}✓ Password copied to clipboard!${NC}"
    echo ""
elif command -v xclip &> /dev/null; then
    echo "$DB_PASSWORD" | xclip -selection clipboard
    echo -e "${GREEN}✓ Password copied to clipboard!${NC}"
    echo ""
fi

# Start SSM tunnel
echo -e "${GREEN}🚇 Starting SSM tunnel...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the tunnel${NC}"
echo ""

aws ssm start-session \
    --target "$BASTION_ID" \
    --region ap-east-2 \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$RDS_ENDPOINT\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5433\"]}"
