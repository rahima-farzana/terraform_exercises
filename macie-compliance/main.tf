/*
Wezva Technologies - Cloud Infrastructure Automation Framework
Component: Enterprise-Wide Passive Data Governance & Sensitive Asset Audit
Author: Adam, Head of Platform
Optimized: Continuous automated discovery, cost-controlled sampling, and event-driven alerting.
*/

# Fetch dynamic account metadata configurations
data "aws_caller_identity" "current" {}

# 1. Activate AWS Macie Account Framework & Enable Automated Sensitive Data Discovery
# 🎯 FIX: Automatically inventories, samples, and scans ALL current and future S3 buckets in this standalone account
resource "aws_macie2_account" "global_macie" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# 2. Provision an Amazon SNS Notification Topic for Security Alerts
resource "aws_sns_topic" "macie_alerts_topic" {
  name = "${var.environment}-macie-security-alerts"
}

# 3. Subscribe the Security Team Email Endpoint to the SNS Topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.macie_alerts_topic.arn
  protocol  = "email"
  endpoint  = var.security_team_email
}

# 4. Configure the SNS Access Policy to allow EventBridge to publish messages to it
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.macie_alerts_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]
    
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"] 
    }
    
    resources = [aws_sns_topic.macie_alerts_topic.arn]
  }
}

# 5. Create the Amazon EventBridge Rule to monitor Macie for major vulnerabilities
resource "aws_cloudwatch_event_rule" "macie_alert_rule" {
  name        = "${var.environment}-macie-incident-alert-trigger"
  description = "Intercepts high-severity PII leaks and secret exposure events"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High", "Medium"]
      }
    }
  })
}

# 6. Bind the EventBridge Rule Target down to your Amazon SNS Email Topic
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.macie_alert_rule.name
  target_id = "SendToSecuritySNSTopic"
  arn       = aws_sns_topic.macie_alerts_topic.arn

  # 🎯 TEXT FORMATTING: Cleans up raw JSON finding data into a readable message for your inbox
  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity.description"
      bucket       = "$.detail.resourcesAffected.s3Object.bucketName"
      object_key   = "$.detail.resourcesAffected.s3Object.key"
      arn          = "$.detail.arn"
    }
    input_template = "\"🚨 AWS MACIE ALERT: Sensitive data leakage detected!\\n\\n- Risk Category: <finding_type>\\n- Severity: <severity>\\n- Affected Bucket: <bucket>\\n- Compromised File Path: <object_key>\\n\\n🔍 View full incident detail report here: <arn>\""
  }
}

# Output the SNS Topic ARN so you can plug it straight into your python test script
output "sns_topic_arn" {
  value       = aws_sns_topic.macie_alerts_topic.arn
  description = "The Amazon Resource Name of the deployed security alerting channel"
}

