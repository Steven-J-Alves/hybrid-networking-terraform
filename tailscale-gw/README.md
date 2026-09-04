# tailscale-gw

Tailscale subnet router EC2 in the hybrid VPC. Enables the VPS (via tailnet) to reach ElastiCache/Aurora inside the VPC without opening them to the public internet.

## Dependencies

- **hybrid-ecs-terraform/network** applied first (VPC + private subnet exist)
- **hybrid-ecs-terraform/bootstrap** applied first (DynamoDB lock table `kriolu-kloud-hybrid-networking-terraform-lock`)
- Tailscale account with a **reusable + preauthorized** auth key generated via https://login.tailscale.com/admin/settings/keys

## Apply

```bash
export TF_VAR_tailscale_auth_key="tskey-auth-XXXXXXXXX"   # keep out of shell history!
AWS_PROFILE=steven-prod terraform init -reconfigure
AWS_PROFILE=steven-prod terraform plan
AWS_PROFILE=steven-prod terraform apply
```

## What it creates

| Resource | Notes |
|---|---|
| IAM role `p-hybrid-tailscale-gw-role` | SSM access only, no SSH keys needed |
| Security group `p-hybrid-tailscale-gw-sg` | Ingress: intra-VPC + optional admin SSH · Egress: all |
| Network interface | `source_dest_check=false` — CRITICAL for forwarding |
| EC2 t4g.nano | Amazon Linux 2023 arm64, user-data installs Tailscale + `tailscale up` |
| Route entries | `100.64.0.0/10 → ENI` in every private route table of the hybrid VPC |

## What to verify after apply

```bash
# 1. Instance running
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[].Instances[].State.Name'

# 2. Tailscale online (in Tailscale admin console — instance should appear with routes advertised)

# 3. Approve subnet routes in Tailscale admin:
#    https://login.tailscale.com/admin/machines/<host>/edit
#    → "Subnet routes" → tick 10.230.0.0/16 → Save

# 4. From VPS, reach a resource inside the VPC
ssh openclaw "ping -c 3 10.230.0.10"    # some private IP in VPC
```

## Idempotency

- `user_data_replace_on_change = true` — changing the auth key or advertised routes replaces the EC2 (short downtime, ~2 min)
- Route table entries are `for_each` on discovered route tables — new private route tables added later are picked up on next apply

## Rotation

Auth key rotation: update `TF_VAR_tailscale_auth_key` + `terraform apply`. Instance is replaced; VPS reconnects automatically via CGNAT routing (existing tailnet IP is preserved because auth key is per-node).
