# Database Access Scripts

## db-tunnel.sh

Creates a secure SSH tunnel to the RDS database using AWS Systems Manager Session Manager.

### Prerequisites

- AWS CLI configured with appropriate credentials
- Session Manager plugin installed: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- jq installed: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### Usage

```bash
./scripts/db-tunnel.sh
```

The script will:
1. Fetch database credentials from AWS Secrets Manager
2. Display pgAdmin connection details
3. Copy password to clipboard (macOS/Linux with xclip)
4. Start SSM tunnel on localhost:5433

### pgAdmin Configuration

After running the script, configure pgAdmin with:

- **Host:** localhost
- **Port:** 5433
- **Database:** shovelheroes
- **Username:** dbadmin
- **Password:** (displayed in terminal/clipboard)

### psql Access

While tunnel is running, connect via psql:

```bash
psql "postgresql://dbadmin:<PASSWORD>@localhost:5433/shovelheroes"
```

### Stopping the Tunnel

Press `Ctrl+C` in the terminal where the tunnel is running.

### Cost Optimization

The bastion host costs ~$7/month. To save costs:

```bash
# Stop bastion when not needed
aws ec2 stop-instances --instance-ids $(terraform output -raw bastion_ssm_instance_id)

# Start when needed
aws ec2 start-instances --instance-ids $(terraform output -raw bastion_ssm_instance_id)
```
