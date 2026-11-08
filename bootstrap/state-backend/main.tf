# Run this ONCE, with local state, before any other stack. Terraform cannot store its
# state in a bucket that does not exist yet, so these buckets are created first and
# every other stack then points its backend.tf at them.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "practice"
      Purpose   = "terraform-state"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_names = {
    for environment in var.environments :
    environment => "tf-state-${environment}-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket" "state" {
  for_each = local.bucket_names

  bucket = each.value

  tags = merge(var.tags, {
    Name        = each.value
    Environment = each.key
  })

  lifecycle {
    # A deleted state bucket means orphaned infrastructure. Remove this line
    # deliberately, and only when you really want to tear the backend down.
    prevent_destroy = true
  }
}

# Versioning lets you roll back a corrupted or mistakenly overwritten state file.
resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest. Swap AES256 for aws:kms plus a key if you need KMS audit trails.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.state

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old state versions are kept for 90 days, then expire, so the bucket does not grow forever.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# Refuse any request that is not sent over TLS.
resource "aws_s3_bucket_policy" "tls_only" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        each.value.arn,
        "${each.value.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
