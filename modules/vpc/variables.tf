variable "name" {
  description = "Name prefix applied to every resource in the VPC (for example practice-dev)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be 2-31 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR block for the VPC (for example 10.0.0.0/16)"
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "vpc_cidr_block must be a valid IPv4 CIDR block such as 10.0.0.0/16."
  }
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across; one public and one private subnet is created per zone"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.availability_zones) >= 1 && length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "availability_zones must contain at least one zone and no duplicates."
  }
}

variable "subnet_newbits" {
  description = "Extra prefix bits added to vpc_cidr_block for each subnet (8 turns a /16 into /24 subnets)"
  type        = number
  default     = 8
  nullable    = false

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 12
    error_message = "subnet_newbits must be between 1 and 12."
  }
}

variable "private_subnet_offset" {
  description = "Subnet number where private subnets start, so they never overlap the public ones (public uses 0 to n-1)"
  type        = number
  default     = 10
  nullable    = false

  validation {
    condition     = var.private_subnet_offset >= length(var.availability_zones)
    error_message = "private_subnet_offset must be at least the number of availability zones, otherwise public and private subnets overlap."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets can reach the internet (NAT gateways cost money while they exist)"
  type        = bool
  default     = true
  nullable    = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheap, practice and dev) instead of one per availability zone (resilient, prod)"
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Extra tags applied to every resource created by this module"
  type        = map(string)
  default     = {}
  nullable    = false
}
