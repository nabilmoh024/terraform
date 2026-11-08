provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

# Read the outputs of the vpc stack from its own state file. This is the
# "remote_state" arrow in the workflow diagram: apply vpc first, then ec2.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/vpc/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  name = "${var.project}-${var.environment}"

  # Same naming rule as bootstrap/state-backend and environments/<env>/backend.hcl,
  # so there is no bucket name to copy into tfvars by hand.
  state_bucket = "tf-state-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project     = var.project
    Environment = var.environment
    Stack       = "ec2"
    ManagedBy   = "Terraform"
  }

  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

module "app" {
  source = "../../../modules/ec2"

  name             = "${local.name}-app"
  vpc_id           = local.vpc_id
  subnet_id        = local.private_subnet_ids[0]
  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size
  ingress_rules    = var.ingress_rules
}
