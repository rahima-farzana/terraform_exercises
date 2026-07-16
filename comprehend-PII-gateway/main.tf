/*
Wezva Technologies - Cloud Infrastructure Automation Framework
Component: Centralised Ingestion Sanitisation & Real-Time PII Gateway
Author: Adam, Head of Platform
Optimized: Decoupled multi-pipeline protection, serverless NLP streaming, and zero-trust data ingestion.
*/

# Fetch dynamic metadata payload context
data "aws_caller_identity" "current" {}

# 1. Compile the real-time zip package out of the local source script
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/dist/pii_gateway_worker.py"
  output_path = "${path.module}/dist/pii_gateway_worker.zip"
}

# 2. Build Custom Lambda IAM Role with scoped S3 and NLP analysis clearances
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-central-pii-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { 
        # 🎯 FIX: Applied the proper native principal identifier for Lambda execution roles
        Service = "lambda.amazonaws.com" 
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.environment}-central-pii-gateway-permissions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "arn:aws:s3:::${var.raw_ingestion_bucket_id}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["comprehend:DetectPiiEntities"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 3. Provision the central AWS Lambda worker function instance
resource "aws_lambda_function" "redaction_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-central-pii-gateway-worker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "pii_gateway_worker.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout_seconds
}

# 4. Grant explicit authorization allowing S3 bucket notifications to invoke Lambda
resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowExecutionFromS3BucketInbound"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redaction_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.raw_ingestion_bucket_id}"
}

# 5. THE REAL-TIME TRIGGER: Hook S3 file uploads directly to the Lambda gateway worker
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.raw_ingestion_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.redaction_lambda.arn
    events              = ["s3:ObjectCreated:*"] 
    filter_suffix       = ".csv"                 
  }

  depends_on = [aws_lambda_permission.allow_s3_trigger]
}

