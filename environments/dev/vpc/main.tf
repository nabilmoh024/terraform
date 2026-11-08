provider "aws" {
  region = var.aws_region

  # Applied to every taggable resource, so modules do not need to repeat these.
  default_tags {
    tags = local.tags
  }
}

locals {
  name = "${var.project}-${var.environment}"

  tags = {
    Project     = var.project
    Environment = var.environment
    Stack       = "vpc"
    ManagedBy   = "Terraform"
  }
}

# Step 3 of the flow: values from terraform.tfvars arrive here as var.*
# and are handed to the module's own variables.tf inputs.
module "vpc" {
  source = "../../../modules/vpc"

  name               = local.name
  vpc_cidr_block     = var.vpc_cidr_block
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}
