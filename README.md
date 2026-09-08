# hybrid-networking-terraform

The **glue** between AWS and the Contabo VPS. Everything ECS-related lives in [`../../../ecs/hybrid-ecs-terraform/`](../../../ecs/hybrid-ecs-terraform/) — this repo stays small on purpose: infra that rarely changes after it stabilises.

## Stacks

| # | Stack | What it creates | Depends on |
|---|---|---|---|
| 1 | `tailscale-gw/` | EC2 `t4g.small` subnet router (Amazon Linux 2023 arm64) in the hybrid VPC private subnet. Runs `tailscale up --advertise-routes=10.230.0.0/16 --accept-routes` via user-data. VPC route tables get an entry `100.64.0.0/10 → ENI` so AWS-side workloads can reach the tailnet. `source_dest_check=false` to allow forwarding. | hybrid-ecs-terraform/network |
| 2 | `ecs-anywhere-activation/` | SSM activation + IAM role `ecsAnywhereRole` — outputs (`activation_id`, `activation_code`, `cluster_name`, `region`) consumed by `hybrid-vps-ansible` role `ecs-anywhere` via cross-project artifact. | hybrid-ecs-terraform/cluster |

## CI/CD

Root `.gitlab-ci.yml` has both stacks with validate → plan → apply → destroy, gated by manual approval + `environment: hybrid-prod`. Destroy jobs have `needs: []` — decoupled from apply.

**Required CI vars (protected+masked):**
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — from `kk-hybrid-terraform-ci`
- `TF_VAR_tailscale_auth_key` — reusable + **preauthorized routes** flag

**Cross-project artifact:** `eca:apply` publishes `tf-outputs.json`. The Ansible pipeline pulls it via GitLab API (`GITLAB_API_TOKEN`, read_api scope) because cross-project `needs:` is EE-only.

## Companion repositories

- ECS side (VPC, cluster, apps): [`../../../ecs/hybrid-ecs-terraform/`](../../../ecs/hybrid-ecs-terraform/)
- VPS-side config: [`../hybrid-vps-ansible/`](../hybrid-vps-ansible/)

## Isolation

Same S3 state bucket, isolated by prefix:

| Item | Value |
|---|---|
| State bucket | `kriolu-kloud-terraform-tfstates` |
| State key prefix | `hybrid-networking/<stack>/<env>/*.tfstate` |
| DynamoDB locks | `kriolu-kloud-hybrid-{tsgw,eca}-terraform-lock` |
| IAM CI user | `kk-hybrid-terraform-ci` (same as hybrid-ecs) |

## Gotchas learned

- **`t4g.nano` OOM-kills `dnf install tailscale`** during user-data (512 MB not enough). Use `t4g.small`.
- **`user_data_replace_on_change` only fires when user_data actually changes** — modifying `instance_type` in place does stop/start, and cloud-init skips user-data on second boot. If tsgw needs a fresh user-data run, `aws ec2 terminate-instances` and let TF recreate.
- **Auth key must have "preauthorize routes"** in the Tailscale admin — otherwise routes are advertised but stay pending manual approval, VPS sees nothing.
- **Route53 hosted zone is NOT created here** — assumed pre-existing (created outside TF, shared across projects).

## Status

**Live via CI.** Both stacks tested apply + destroy end-to-end. Tsgw EC2 confirmed joining tailnet with `PrimaryRoutes=[10.230.0.0/16]`; VPS receives routes with `RouteAll: true`.
