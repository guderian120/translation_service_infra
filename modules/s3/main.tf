# modules/s3/main.tf
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "${var.prefix}-input-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "output_bucket" {
  bucket        = "${var.prefix}-output-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# Enable bucket versioning for additional protection
resource "aws_s3_bucket_versioning" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block ALL public access at the bucket level
resource "aws_s3_bucket_public_access_block" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  block_public_acls       = true
  block_public_policy     = false 
  ignore_public_acls      = true
  restrict_public_buckets = false 
}

# Fine-grained bucket policy
resource "aws_s3_bucket_policy" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id
  policy = data.aws_iam_policy_document.output_bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.output_bucket]
}

data "aws_iam_policy_document" "output_bucket_policy" {
  # Deny all non-HTTPS traffic
  statement {
    sid    = "EnforceSecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.output_bucket.arn,
      "${aws_s3_bucket.output_bucket.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow GET requests only from your domain(s)
  statement {
    sid    = "AllowFrontendAccess"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.output_bucket.arn}/*"]
    condition {
      test     = "StringLike"
      variable = "aws:Referer"
      values   = var.allowed_referers
    }
  }
}

# CORS configuration for your frontend
resource "aws_s3_bucket_cors_configuration" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"] # Only allow reads
    allowed_origins = var.allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = var.lambda_upload_handler_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_upload_handler_arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}