data "aws_partition" "current" {}

# Newest Amazon Linux 2023 AMI, skipped when the caller pins ami_id.
data "aws_ami" "amazon_linux" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-${var.architecture}"]
  }

  filter {
    name   = "architecture"
    values = [var.architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
}

# ---------------------------------------------------------------------------
# Network access: no inbound unless ingress_rules asks for it, all outbound allowed
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.this.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.name}-all-outbound" })
}

resource "aws_vpc_security_group_ingress_rule" "allowed" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id

  description = coalesce(each.value.description, each.key)
  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.ip_protocol
  cidr_ipv4   = each.value.cidr_ipv4

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# ---------------------------------------------------------------------------
# Session Manager access (no SSH keys, no open port 22)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  count = var.enable_ssm ? 1 : 0

  name_prefix = "${var.name}-ssm-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  count = var.enable_ssm ? 1 : 0

  name_prefix = "${var.name}-ssm-"
  role        = aws_iam_role.this[0].name

  tags = var.tags
}

# ---------------------------------------------------------------------------
# The instance
# ---------------------------------------------------------------------------

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = one(aws_iam_instance_profile.this[*].name)
  monitoring                  = var.enable_detailed_monitoring
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data != null

  # IMDSv2 only: blocks the classic SSRF-to-credentials attack path.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags        = merge(var.tags, { Name = var.name })
  volume_tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # "Newest AMI" changes whenever Amazon publishes a release. Ignoring it stops a
    # surprise replacement on the next plan. To roll to a new AMI on purpose, run:
    #   terraform apply -replace='module.app.aws_instance.this'
    ignore_changes = [ami]
  }
}
