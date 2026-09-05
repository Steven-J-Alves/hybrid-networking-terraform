variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Environment prefix"
  type        = string
  default     = "prod"
}

variable "ecs_cluster_name" {
  description = "ECS cluster the VPS will register into (created by hybrid-ecs-terraform/cluster)"
  type        = string
  default     = "p-hybrid-apis"
}

variable "activation_registration_limit" {
  description = "How many container instances can register with this activation (1 VPS today; increase if more VPS)"
  type        = number
  default     = 1
}

variable "activation_description" {
  description = "Human-readable description shown in SSM console"
  type        = string
  default     = "Hybrid VPS registration into p-hybrid-apis ECS cluster"
}
