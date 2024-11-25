provider "aws" {
  region = "us-east-1"
}

data "aws_acm_certificate" "shaheryar_cert" {
  domain   = "*.shaheryar.site"
  most_recent = true
}

resource "aws_api_gateway_rest_api" "shaheryar_api" {
  name = "shaheryarAPI"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_dynamodb_table" "shaheryardb" {
  name         = "shaheryardb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_lambda_function" "shaheryarlambdafunction" {
  function_name = "shaheryarlambdafunction"
  role          = "arn:aws:iam::577638354548:role/service-role/shaheryarlambdafunction-role"

  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  filename      = "lambda_function.zip"

  memory_size   = 128
  timeout       = 3
  package_type  = "Zip"

  ephemeral_storage {
    size = 512
  }

  tracing_config {
    mode = "PassThrough"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_s3_bucket" "shaheryar2" {
  bucket = "shaheryar2"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_s3_bucket_policy" "resume_bucket_policy" {
  bucket = aws_s3_bucket.shaheryar2.bucket
  policy = jsonencode({
    Id = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Action    = "s3:GetObject"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::577638354548:distribution/E1THO19NVSBLJD"
          }
        }
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Resource = "arn:aws:s3:::shaheryar2/*"
        Sid      = "AllowCloudFrontServicePrincipal"
      },
    ]
    Version = "2008-10-17"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_s3_bucket_versioning" "resume_bucket_versioning" {
  bucket = aws_s3_bucket.shaheryar2.bucket
  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "resume_bucket_sse" {
  bucket = aws_s3_bucket.shaheryar2.bucket

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_cloudfront_distribution" "my_distribution" {
  aliases             = ["*.shaheryar.site"]
  comment             = "Cloud Resume Challenge"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  wait_for_deployment = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = "shaheryar2"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name              = "shaheryar2.s3.amazonaws.com"
    origin_id                = "shaheryar2"
    origin_access_control_id = "E1THO19NVSBLJD"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.shaheryar_cert.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

output "acm_certificate_arn" {
  value = data.aws_acm_certificate.shaheryar_cert.arn
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.shaheryar_api.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.shaheryardb.name
}

output "lambda_function_arn" {
  value = aws_lambda_function.shaheryarlambdafunction.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.shaheryar2.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.my_distribution.domain_name
}

