# Native tests (Terraform 1.7+ for mock_provider). No AWS account or credentials needed:
#   cd modules/ec2 && terraform init && terraform test
mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  name      = "test-app"
  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "Root volume must be encrypted."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.allowed) == 0
    error_message = "No inbound rules should exist unless ingress_rules is set."
  }

  assert {
    condition     = length(aws_iam_role.this) == 1
    error_message = "SSM role should be created by default."
  }
}

run "ssm_can_be_disabled" {
  command = plan

  variables {
    enable_ssm = false
  }

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_iam_instance_profile.this) == 0
    error_message = "No IAM resources should be created when enable_ssm is false."
  }
}

run "ingress_rules_create_one_rule_each" {
  command = plan

  variables {
    ingress_rules = {
      http_from_vpc = {
        from_port = 80
        to_port   = 80
        cidr_ipv4 = "10.0.0.0/16"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.allowed) == 1
    error_message = "Expected exactly one ingress rule."
  }
}

run "pinned_ami_skips_lookup" {
  command = plan

  variables {
    ami_id = "ami-0fedcba9876543210"
  }

  assert {
    condition     = length(data.aws_ami.amazon_linux) == 0
    error_message = "AMI lookup should be skipped when ami_id is set."
  }
}

run "rejects_bad_instance_type" {
  command = plan

  variables {
    instance_type = "huge"
  }

  expect_failures = [var.instance_type]
}

run "rejects_bad_vpc_id" {
  command = plan

  variables {
    vpc_id = "not-a-vpc"
  }

  expect_failures = [var.vpc_id]
}
