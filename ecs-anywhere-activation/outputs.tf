output "activation_id" {
  description = "SSM Activation ID — consumed by ecs-anywhere Ansible role"
  value       = aws_ssm_activation.vps.id
  sensitive   = true
}

output "activation_code" {
  description = "SSM Activation Code — consumed by ecs-anywhere Ansible role"
  value       = aws_ssm_activation.vps.activation_code
  sensitive   = true
}

output "iam_role_name" {
  description = "IAM role name assumed by the registered VPS"
  value       = aws_iam_role.ecs_anywhere.name
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ecs_anywhere.arn
}

output "expiration_date" {
  description = "When this activation stops accepting new registrations (24h from apply)"
  value       = aws_ssm_activation.vps.expiration_date
}

output "ecs_cluster_name" {
  description = "Cluster the VPS will join (passed through for Ansible convenience)"
  value       = var.ecs_cluster_name
}

output "aws_region" {
  description = "Region for the ECS agent config"
  value       = var.aws_region
}
