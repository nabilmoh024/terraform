variable "name" {
  description = "Name of the instance, also used as a prefix for its security group and IAM role (for example practice-dev-app)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be 2-31 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the instance and its security group are created in (output vpc_id of the vpc stack)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must look like vpc-0123456789abcdef0."
  }
}

variable "subnet_id" {
  description = "ID of the subnet to launch into; use a private subnet for anything that does not need a public IP"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^subnet-[0-9a-f]+$", var.subnet_id))
    error_message = "subnet_id must look like subnet-0123456789abcdef0."
  }
}

variable "instance_type" {
  description = "EC2 instance type, for example t3.micro (must match the architecture variable)"
  type        = string
  default     = "t3.micro"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[0-9][a-z]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like t3.micro or m5.large."
  }
}

variable "architecture" {
  description = "CPU architecture of the AMI looked up when ami_id is null: x86_64 (t3, m5, c5) or arm64 (t4g, m6g, c6g)"
  type        = string
  default     = "x86_64"
  nullable    = false

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "ami_id" {
  description = "AMI to launch. When null, the newest Amazon Linux 2023 AMI for the chosen architecture is looked up automatically."
  type        = string
  default     = null

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be null or look like ami-0123456789abcdef0."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB"
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "root_volume_size must be between 8 and 1000 GiB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type for the root volume"
  type        = string
  default     = "gp3"
  nullable    = false

  validation {
    condition     = contains(["gp3", "gp2"], var.root_volume_type)
    error_message = "root_volume_type must be gp3 or gp2."
  }
}

variable "enable_ssm" {
  description = "Attach an IAM role with AmazonSSMManagedInstanceCore so you can open a shell with Session Manager instead of SSH keys"
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_detailed_monitoring" {
  description = "Enable 1-minute CloudWatch detailed monitoring (extra cost)"
  type        = bool
  default     = false
  nullable    = false
}

variable "ingress_rules" {
  description = "Inbound security group rules keyed by a short stable name, for example { http_from_vpc = { from_port = 80, to_port = 80, cidr_ipv4 = \"10.0.0.0/16\" } }. Empty means no inbound traffic at all."
  type = map(object({
    description = optional(string)
    from_port   = number
    to_port     = number
    ip_protocol = optional(string, "tcp")
    cidr_ipv4   = string
  }))
  default  = {}
  nullable = false
}

variable "user_data" {
  description = "Cloud-init or shell script run on first boot. Never put secrets here; it is stored in plain text. Changing it replaces the instance."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags applied to every resource created by this module"
  type        = map(string)
  default     = {}
  nullable    = false
}
