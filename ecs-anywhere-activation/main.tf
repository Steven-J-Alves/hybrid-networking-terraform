# ecs-anywhere-activation
#
# Creates the SSM Activation + IAM role that lets an external VPS register
# itself as an ECS container instance in the hybrid-apis cluster.
#
# Outputs `activation_id` + `activation_code` are consumed by the Ansible
# role `ecs-anywhere` on the VPS side (see hybrid-vps-ansible/).

# ---------------------------------------------------------------------------
# IAM role for the SSM-managed instance (ECS Anywhere)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_anywhere" {
  name        = "${var.environment_name}-hybrid-ecs-anywhere-role"
  description = "Role assumed by external ECS Anywhere container instances (VPS) via SSM"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Managed policies needed for ECS Anywhere:
#   - AmazonSSMManagedInstanceCore : allows the SSM agent to phone home
#   - AmazonEC2ContainerServiceforEC2Role : allows the ECS agent to poll the cluster
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ecs_anywhere.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_anywhere.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Extra: allow the VPS to pull images from ECR
resource "aws_iam_role_policy" "ecr_read" {
  name = "${var.environment_name}-hybrid-ecs-anywhere-ecr-read"
  role = aws_iam_role.ecs_anywhere.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

# ---------------------------------------------------------------------------
# SSM Activation — one-shot credential the VPS uses to register itself
#
# expiration_date is 24h from apply. If Ansible doesn't consume it in time,
# `terraform apply` again to rotate. Once consumed (registered_instance_count > 0),
# the VPS keeps its SSM identity indefinitely via rotating short-lived certs.
# ---------------------------------------------------------------------------

resource "aws_ssm_activation" "vps" {
  name               = "${var.environment_name}-hybrid-vps"
  description        = var.activation_description
  iam_role           = aws_iam_role.ecs_anywhere.name
  registration_limit = var.activation_registration_limit
  expiration_date    = timeadd(timestamp(), "24h")

  # Rotate the activation on every apply — cheap, ensures fresh code if register fails
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [expiration_date]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.ecs_agent,
  ]
}
