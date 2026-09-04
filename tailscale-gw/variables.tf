variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Environment prefix (p = prod, h = homolog)"
  type        = string
  default     = "p"
}

variable "hybrid_vpc_cidr" {
  description = "CIDR of the hybrid VPC created by hybrid-ecs-terraform/network (used only for tagging/lookup)"
  type        = string
  default     = "10.230.0.0/16"
}

variable "tailscale_auth_key" {
  description = "Reusable + preauthorized Tailscale auth key (rotate periodically). Passed via TF_VAR_tailscale_auth_key or -var-file."
  type        = string
  sensitive   = true
}

variable "advertise_routes" {
  description = "CIDRs advertised into the tailnet. Must match hybrid VPC + any peered ranges."
  type        = list(string)
  default     = ["10.230.0.0/16"]
}

variable "cgnat_range" {
  description = "Tailscale CGNAT range — used for VPC route table entry pointing at the subnet router ENI."
  type        = string
  default     = "100.64.0.0/10"
}

variable "instance_type" {
  description = "EC2 instance type for the subnet router. t4g.nano is enough for admin/backup workloads."
  type        = string
  default     = "t4g.nano"
}

variable "ssh_admin_cidrs" {
  description = "CIDRs allowed to SSH into the subnet router (for emergency debug). Leave empty [] to disable SSH ingress."
  type        = list(string)
  default     = []
}
