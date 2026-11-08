# vpc module

Creates a VPC with one public and one private subnet per availability zone, an internet
gateway, routing, and optional NAT gateways (one shared, or one per zone). The default
security group is emptied so nothing can use it by accident.

Environment-specific values (CIDR, zones, NAT choice) are inputs. Nothing is hardcoded.

## Usage

```hcl
module "vpc" {
  source = "../../../modules/vpc"

  name               = "practice-dev"
  vpc_cidr_block     = "10.0.0.0/16"
  availability_zones = ["ap-south-1a", "ap-south-1b"]
  enable_nat_gateway = true
  single_nat_gateway = true
}
```

With a `/16` and the default `subnet_newbits = 8`, public subnets are `10.0.0.0/24`,
`10.0.1.0/24`, ... and private subnets start at `10.0.10.0/24`.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `name` | Name prefix for every resource | `string` | required |
| `vpc_cidr_block` | IPv4 CIDR block for the VPC | `string` | required |
| `availability_zones` | Zones to spread subnets across | `list(string)` | required |
| `subnet_newbits` | Extra prefix bits per subnet | `number` | `8` |
| `private_subnet_offset` | Subnet number where private subnets start | `number` | `10` |
| `enable_nat_gateway` | Create NAT gateway(s) | `bool` | `true` |
| `single_nat_gateway` | One shared NAT instead of one per zone | `bool` | `true` |
| `tags` | Extra tags for every resource | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `vpc_cidr_block` | CIDR block of the VPC |
| `availability_zones` | Zones used, in subnet list order |
| `public_subnet_ids` | Public subnet IDs, ordered like the zones |
| `private_subnet_ids` | Private subnet IDs, ordered like the zones |
| `nat_gateway_public_ips` | NAT public IPs keyed by zone |

## Requirements

| Name | Version |
|---|---|
| terraform (or tofu) | >= 1.10 |
| aws | ~> 5.0 |

Run the tests with `terraform init && terraform test`. They use a mocked provider, so no
AWS credentials are needed.
