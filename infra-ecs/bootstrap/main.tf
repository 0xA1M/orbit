# Configure the AWS Provider
provider "aws" {
  region = var.region

  # tag every resource created by this root with the shared tags map
  default_tags {
    tags = var.tags
  }
}

# the one and only state bucket for the whole project
resource "aws_s3_bucket" "orbit_tfstate_bucket" {
  bucket = var.bucket_name
}

# keep every old state file as a new version, so a bad apply can be recovered
resource "aws_s3_bucket_versioning" "orbit_tfstate_bucket_versioning" {
  bucket = aws_s3_bucket.orbit_tfstate_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# make the state bucket unreachable from the public internet, four layers deep:
# block acls, block policies, ignore stray acls, restrict whatever remains
resource "aws_s3_bucket_public_access_block" "orbit_tfstate_bucket_pub_access" {
  bucket = aws_s3_bucket.orbit_tfstate_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# encrypt every object at rest with SSE-S3 (AES256, AWS managed keys)
resource "aws_s3_bucket_server_side_encryption_configuration" "orbit_tfstate_bucket_sse" {
  bucket = aws_s3_bucket.orbit_tfstate_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
