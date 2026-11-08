# Try the ec2 module on its own by pairing it with the vpc module. No environments, no
# remote state, so nothing else is needed:
#   terraform init && terraform apply
#   aws ssm start-session --target $(terraform output -raw instance_id)
#   terraform destroy      <- when you are done
# One shared NAT gateway is on so Session Manager can reach the private instance. It
# bills by the hour while it exists, so destroy this example when you finish.
provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source = "../../../vpc"

  name               = "ec2-example"
  vpc_cidr_block     = "10.30.0.0/16"
  availability_zones = ["ap-south-1a", "ap-south-1b"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "app" {
  source = "../.."

  name      = "ec2-example-app"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_ids[0]
}

output "instance_id" {
  description = "ID of the example instance"
  value       = module.app.instance_id
}
