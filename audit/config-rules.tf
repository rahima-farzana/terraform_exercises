resource "aws_iam_role" "config_role" {
  name = "${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { 
        Service = "config.amazonaws.com" 
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main_recorder" {
  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main_channel" {
  name           = "${var.environment}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.security_logs.id

  depends_on = [
    aws_config_configuration_recorder.main_recorder,
    aws_s3_bucket_policy.security_logs_policy
  ]
}

resource "aws_config_configuration_recorder_status" "config_status" {
  name       = aws_config_configuration_recorder.main_recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main_channel]
}

resource "aws_config_config_rule" "iam_mfa_enabled" {
  name       = "iam-user-mfa-enabled-check"
  depends_on = [aws_config_configuration_recorder_status.config_status]

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }
}

