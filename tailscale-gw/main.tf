# tailscale-gw — Tailscale subnet router EC2 in the hybrid VPC.
#
# Depends on hybrid-ecs-terraform/network having been applied first (VPC + private subnet exist).
# We look them up via data sources filtered by tags.

# ---------------------------------------------------------------------------
# Data sources — hybrid VPC + private subnet (created by hybrid-ecs-terraform/network)
# ---------------------------------------------------------------------------

data "aws_vpc" "hybrid" {
  filter {
    name   = "cidr"
    values = [var.hybrid_vpc_cidr]
  }
}

data "aws_subnets" "hybrid_private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.hybrid.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*hybrid-vpc-private-*"]
  }
}

data "aws_route_tables" "hybrid_private" {
  vpc_id = data.aws_vpc.hybrid.id
  filter {
    name   = "tag:Name"
    values = ["*hybrid-vpc-private-*"]
  }
}

# Amazon Linux 2023 arm64 (matches t4g instance types)
data "aws_ssm_parameter" "amzn2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# ---------------------------------------------------------------------------
# IAM role for the EC2 (SSM access — no SSH needed for admin)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "tailscale_gw" {
  name = "${var.environment_name}-hybrid-tailscale-gw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.tailscale_gw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "tailscale_gw" {
  name = "${var.environment_name}-hybrid-tailscale-gw-profile"
  role = aws_iam_role.tailscale_gw.name
}

# ---------------------------------------------------------------------------
# Security group — outbound all, no inbound by default (SSM for admin)
# ---------------------------------------------------------------------------

resource "aws_security_group" "tailscale_gw" {
  name        = "${var.environment_name}-hybrid-tailscale-gw-sg"
  description = "Tailscale subnet router — outbound to internet + intra-VPC"
  vpc_id      = data.aws_vpc.hybrid.id

  ingress {
    description = "Intra-VPC (traffic forwarded from VPS via tailnet)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.hybrid_vpc_cidr]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_admin_cidrs) > 0 ? [1] : []
    content {
      description = "SSH admin (emergency)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_admin_cidrs
    }
  }

  egress {
    description = "All outbound (Tailscale coordination + intra-VPC)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-hybrid-tailscale-gw-sg"
  }
}

# ---------------------------------------------------------------------------
# EC2 subnet router — single instance (recover via ASG later if needed)
# ---------------------------------------------------------------------------

resource "aws_network_interface" "tailscale_gw" {
  subnet_id       = data.aws_subnets.hybrid_private.ids[0]
  security_groups = [aws_security_group.tailscale_gw.id]

  # CRITICAL — allow forwarding packets to/from tailnet CIDR
  source_dest_check = false

  tags = {
    Name = "${var.environment_name}-hybrid-tailscale-gw-eni"
  }
}

resource "aws_instance" "tailscale_gw" {
  ami                  = data.aws_ssm_parameter.amzn2023_arm64.value
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.tailscale_gw.name

  network_interface {
    network_interface_id = aws_network_interface.tailscale_gw.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    tailscale_auth_key = var.tailscale_auth_key
    advertise_routes   = join(",", var.advertise_routes)
    hostname           = "${var.environment_name}-hybrid-tailscale-gw"
  })

  # Rotate user-data changes force replacement (auth key rotation)
  user_data_replace_on_change = true

  tags = {
    Name = "${var.environment_name}-hybrid-tailscale-gw"
    Role = "tailscale-subnet-router"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Route table entry — 100.64.0.0/10 (Tailscale CGNAT) → ENI of subnet router
# Added to every private route table in the hybrid VPC.
# ---------------------------------------------------------------------------

resource "aws_route" "tailnet_via_gw" {
  for_each = toset(data.aws_route_tables.hybrid_private.ids)

  route_table_id         = each.value
  destination_cidr_block = var.cgnat_range
  network_interface_id   = aws_network_interface.tailscale_gw.id
}
