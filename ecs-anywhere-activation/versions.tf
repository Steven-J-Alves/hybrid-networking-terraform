terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "kriolu-kloud-terraform-tfstates"
    region         = "us-east-1"
    key            = "hybrid-networking/ecs-anywhere-activation/prod/activation-us-east-1.tfstate"
    dynamodb_table = "kriolu-kloud-hybrid-networking-terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "kriolu-kloud"
      Scope     = "hybrid-networking"
      Component = "ecs-anywhere-activation"
      ManagedBy = "terraform"
    }
  }
}
