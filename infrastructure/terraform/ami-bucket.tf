resource "aws_s3_bucket" "ami" {
  bucket        = local.ami_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "ami" {
  bucket = aws_s3_bucket.ami.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "ami" {
  bucket = aws_s3_bucket.ami.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "ami" {
  bucket = aws_s3_bucket.ami.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ami" {
  bucket = aws_s3_bucket.ami.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "ami_bucket_name" {
  value       = aws_s3_bucket.ami.bucket
  description = "Name of the S3 bucket used for temporary AMI uploads."
}
