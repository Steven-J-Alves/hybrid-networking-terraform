# hybrid-networking-terraform

Terraform stacks that glue **AWS ↔ VPS** for the hybrid architecture. This is intentionally SMALL — everything ECS-related lives in `../../../ecs/hybrid-ecs-terraform/`.

## Stacks

| # | Stack | What it creates | Depends on |
|---|---|---|---|
| 1 | `tailscale-gw/` | EC2 t4g.nano subnet router in `hybrid-ecs-terraform/network/` VPC, ASG min=max=1, `source_dest_check=false`, route table entry `100.64.0.0/10 → ENI` | hybrid-ecs-terraform/network |
| 2 | `ecs-anywhere-activation/` | SSM Activation + IAM role `ecsAnywhereRole` — outputs consumed by `hybrid-vps-ansible` role `ecs-anywhere` | hybrid-ecs-terraform/cluster |
| 3 | `dns/` | Route53 **private** hosted zone `kriolu-kloud.cv` associated with hybrid VPC — resolves `api-*-internal.kriolu-kloud.cv` inside VPC to the private ALB | hybrid-ecs-terraform/cluster (ALB private DNS) |

## Isolation

Same S3 state bucket as everything else, isolated by prefix:

| Item | Value |
|---|---|
| State bucket | `kriolu-kloud-terraform-tfstates` |
| State key prefix | `hybrid-networking/<stack>/<env>/*.tfstate` |
| DynamoDB lock | `kriolu-kloud-hybrid-networking-terraform-lock` (single table, LockID discriminates by state path) |
| IAM CI user | `kk-hybrid-terraform-ci` (same as hybrid-ecs) |

## Why NOT in hybrid-ecs-terraform?

Separation of concerns:
- **hybrid-ecs-terraform** = infra que evolui com apps (task defs, services, autoscaling — mexe muito)
- **hybrid-networking-terraform** = glue infra que praticamente não muda depois de estabilizada (Tailscale gw, SSM activation, private zone)

Blast radius diferente. Um `terraform destroy` no hybrid-ecs não parte o tunnel Tailscale nem o registration ECS Anywhere.

## Companion

- Terraform que já existe do lado ECS: `../../../ecs/hybrid-ecs-terraform/`
- Ansible para o VPS: `../hybrid-vps-ansible/`

## Status

**Skeleton** — folders vazias. A ser preenchidas em Fases 1, 5, 3 (por essa ordem, ver `.claude/topicos/hybrid-architecture/CONTEXTO.md` secção "Sequência de execução").
