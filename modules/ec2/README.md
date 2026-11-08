# ec2 module

Launches one EC2 instance with secure defaults: IMDSv2 required, encrypted root volume,
no inbound traffic unless you add rules, and Session Manager access through an IAM role
(no SSH keys, no open port 22). When `ami_id` is null it uses the newest Amazon Linux 2023
AMI for the chosen architecture.

## Usage

```hcl
module "app" {
  source = "../../../modules/ec2"

  name          = "practice-dev-app"
  vpc_id        = "vpc-0123456789abcdef0"
  subnet_id     = "subnet-0123456789abcdef0"
  instance_type = "t3.micro"

  ingress_rules = {
    http_from_vpc = {
      from_port = 80
      to_port   = 80
      cidr_ipv4 = "10.0.0.0/16"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `name` | Instance name and prefix for its security group and role | `string` | required |
| `vpc_id` | VPC for the security group | `string` | required |
| `subnet_id` | Subnet to launch into | `string` | required |
| `instance_type` | EC2 instance type | `string` | `"t3.micro"` |
| `architecture` | `x86_64` or `arm64`, used for the AMI lookup | `string` | `"x86_64"` |
| `ami_id` | AMI to launch; null means newest Amazon Linux 2023 | `string` | `null` |
| `root_volume_size` | Root volume size in GiB | `number` | `20` |
| `root_volume_type` | `gp3` or `gp2` | `string` | `"gp3"` |
| `enable_ssm` | Attach the Session Manager role | `bool` | `true` |
| `enable_detailed_monitoring` | 1-minute CloudWatch metrics | `bool` | `false` |
| `ingress_rules` | Inbound rules keyed by a stable name | `map(object)` | `{}` |
| `user_data` | First-boot script; no secrets | `string` | `null` |
| `tags` | Extra tags for every resource | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | ID of the instance |
| `private_ip` | Private IP address |
| `security_group_id` | Instance security group, for other stacks to allow in |
| `ami_id` | AMI the instance was launched from |
| `iam_role_name` | SSM role name, or null when `enable_ssm` is false |

## Requirements

| Name | Version |
|---|---|
| terraform (or tofu) | >= 1.10 |
| aws | ~> 5.0 |

The AMI is ignored after creation (`ignore_changes = [ami]`) so a new Amazon release does
not replace the instance. To roll to a new AMI on purpose:
`terraform apply -replace='module.app.aws_instance.this'`.

Run the tests with `terraform init && terraform test`. They use a mocked provider, so no
AWS credentials are needed.
