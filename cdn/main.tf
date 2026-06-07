provider "aws" {
  region = "ap-south-1" # Replace with your desired region
}

# =========================================================================
# Core Storage Tier (Always Created)
# =========================================================================

# Create S3 bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = var.bucket_name
  force_destroy = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "example_versioning" {
  bucket = aws_s3_bucket.example_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Create lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "example_lifecycle" {
  bucket = aws_s3_bucket.example_bucket.id

  rule {
    id     = "lifecycle-policy"
    status = "Enabled"

    # Transition objects to STANDARD_IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition objects to GLACIER after 365 days
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # Expire objects after 2 years
    expiration {
      days = 730
    }

    # Manage noncurrent versions of objects
    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# =========================================================================
# Conditional CDN & Security Infrastructure (Toggled via Flag)
# =========================================================================

# 1. Block All Public Access to the S3 Bucket (Enforce Private State)
resource "aws_s3_bucket_public_access_block" "example_bucket_privacy" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.example_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Configure CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "s3-payment-ui-oac-${aws_s3_bucket.example_bucket.bucket}"
  description                       = "OAC handshake configuration for securing static web artifacts"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3. Create CloudFront Distribution (The CDN Tier)
resource "aws_cloudfront_distribution" "s3_distribution" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.example_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.example_bucket.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac[0].id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Fintech Checkout UI Frontend Distribution Network"
  default_root_object = "index.html"

  # Optimize caching layers for high-velocity static browser bundles
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.example_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # SPA Routing Engine: Catches 403/404 pathing blocks and redirects safely into React Router
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 4. Attach IAM Bucket Policy to allow CloudFront Access
resource "aws_s3_bucket_policy" "allow_cloudfront_oac" {
  count = var.enable_cloudfront ? 1 : 0

  # Explicitly wait until public blocks are applied to prevent timing race-conditions
  depends_on = [aws_s3_bucket_public_access_block.example_bucket_privacy]
  bucket     = aws_s3_bucket.example_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.example_bucket.arn}/*"
        Condition = {
          ArnLike = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution[0].arn
          }
        }
      }
    ]
  })
}

# =========================================================================
# Infrastructure Pipeline Outputs
# =========================================================================
output "s3_bucket_name" {
  value       = aws_s3_bucket.example_bucket.id
  description = "The name of the created storage bucket"
}

output "cloudfront_endpoint_url" {
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.s3_distribution[0].domain_name}" : "CDN Not Enabled"
  description = "The direct, secure web address to check the live UI (if enabled)"
}
