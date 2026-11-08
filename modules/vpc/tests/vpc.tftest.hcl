# Native tests (Terraform 1.7+ for mock_provider). No AWS account or credentials needed:
#   cd modules/vpc && terraform init && terraform test
mock_provider "aws" {}

variables {
  name               = "test"
  vpc_cidr_block     = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

run "one_public_and_private_subnet_per_zone" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected one public and one private subnet per availability zone."
  }

  assert {
    condition     = aws_subnet.public["us-east-1a"].cidr_block == "10.0.0.0/24"
    error_message = "First public subnet should be 10.0.0.0/24."
  }

  assert {
    condition     = aws_subnet.private["us-east-1a"].cidr_block == "10.0.10.0/24"
    error_message = "First private subnet should be 10.0.10.0/24."
  }
}

run "single_nat_gateway_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.egress) == 1
    error_message = "Default should create exactly one shared NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_nat) == 2
    error_message = "Every private route table should route through the NAT gateway."
  }
}

run "nat_gateway_per_zone_when_not_single" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.egress) == 2
    error_message = "Expected one NAT gateway per availability zone."
  }
}

run "no_nat_gateway_when_disabled" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.egress) == 0 && length(aws_route.private_nat) == 0
    error_message = "No NAT gateway or private default route should exist when NAT is disabled."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr_block = "not-a-cidr"
  }

  expect_failures = [var.vpc_cidr_block]
}

run "rejects_overlapping_private_offset" {
  command = plan

  variables {
    private_subnet_offset = 1
  }

  expect_failures = [var.private_subnet_offset]
}
