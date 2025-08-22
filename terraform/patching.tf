# ========================================
# SSM Patch Management Configuration
# ========================================

# SSM Patch Baseline for Amazon Linux 2023
resource "aws_ssm_patch_baseline" "amazon_linux" {
  count = var.create_patch_baseline ? 1 : 0

  name             = "${var.project_name}-${var.env}-amazon-linux-baseline"
  description      = "Patch baseline for Amazon Linux 2023 systems in ${var.env} environment"
  operating_system = "AMAZON_LINUX_2023"

  # Approval rules for patches
  approval_rule {
    approve_after_days  = 0
    compliance_level    = "CRITICAL"
    enable_non_security = false

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  # Additional approval rule for non-security patches
  approval_rule {
    approve_after_days  = 7
    compliance_level    = "MEDIUM"
    enable_non_security = true

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Bugfix", "Enhancement", "Recommended"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Medium", "Low"]
    }
  }

  # Rejected patches (if any specific patches need to be excluded)
  rejected_patches_action = "BLOCK"

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-${var.env}-patch-baseline"
    PatchGroup = "${var.project_name}-${var.env}"
  })
}

# Patch Group association
resource "aws_ssm_patch_group" "main" {
  count = var.create_patch_baseline ? 1 : 0

  baseline_id = aws_ssm_patch_baseline.amazon_linux[0].id
  patch_group = "${var.project_name}-${var.env}"
}

# ========================================
# State Manager Association for Automated Patching
# ========================================

# State Manager Association for patch deployment
resource "aws_ssm_association" "patch_deployment" {
  name                = "AWS-RunPatchBaseline"
  association_name    = "${var.project_name}-${var.env}-patch-deployment"
  schedule_expression = var.patch_schedule

  # Target instances by patch group tag
  targets {
    key    = "tag:PatchGroup"
    values = ["${var.project_name}-${var.env}"]
  }

  # Parameters for the patch baseline execution
  parameters = {
    Operation    = "Install"
    RebootOption = "RebootIfNeeded"
  }

  # Output location for patch logs
  output_location {
    s3_bucket_name = aws_s3_bucket.patch_logs.bucket
    s3_key_prefix  = "patch-logs/${var.env}/"
  }

  # Compliance severity
  compliance_severity = "CRITICAL"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-patch-association"
  })
}

# State Manager Association for patch compliance scanning
resource "aws_ssm_association" "patch_compliance_scan" {
  name                = "AWS-RunPatchBaseline"
  association_name    = "${var.project_name}-${var.env}-patch-compliance-scan"
  schedule_expression = "cron(0 6 ? * MON *)" # Mondays at 6 AM UTC (day after patching)

  # Target instances by patch group tag
  targets {
    key    = "tag:PatchGroup"
    values = ["${var.project_name}-${var.env}"]
  }

  # Parameters for compliance scanning
  parameters = {
    Operation = "Scan"
  }

  # Output location for compliance scan logs
  output_location {
    s3_bucket_name = aws_s3_bucket.patch_logs.bucket
    s3_key_prefix  = "compliance-scans/${var.env}/"
  }

  # Compliance severity
  compliance_severity = "MEDIUM"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-compliance-scan-association"
  })
}

# ========================================
# S3 Bucket for Patch Logs
# ========================================

# S3 bucket for storing patch management logs
resource "aws_s3_bucket" "patch_logs" {
  bucket = "${var.project_name}-${var.env}-patch-logs-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.env}-patch-logs"
    Purpose = "SSM Patch Management Logs"
  })
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  rule {
    id     = "patch_logs_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after retention period (minimum 120 days to be greater than Glacier transition)
    expiration {
      days = max(120, var.backup_retention_days * 4) # Keep patch logs 4x longer than backups, minimum 120 days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ========================================
# CloudWatch Alarms for Patch Compliance
# ========================================

# CloudWatch alarm for patch compliance failures
resource "aws_cloudwatch_metric_alarm" "patch_compliance_failure" {
  alarm_name          = "${var.project_name}-${var.env}-patch-compliance-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ComplianceByPatchGroup"
  namespace           = "AWS/SSM-PatchManager"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors patch compliance failures"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  ok_actions          = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    PatchGroup     = "${var.project_name}-${var.env}"
    ComplianceType = "Patch"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-patch-compliance-alarm"
  })
}

# ========================================
# IAM Permissions for SSM Patch Management
# ========================================

# Additional IAM policy for patch management (attached to existing EC2 role)
resource "aws_iam_role_policy" "ssm_patch_management" {
  name = "${var.project_name}-${var.env}-ssm-patch-management"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.patch_logs.arn,
          "${aws_s3_bucket.patch_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDefaultPatchBaseline",
          "ssm:GetPatchBaseline",
          "ssm:DescribePatchBaselines",
          "ssm:DescribePatchGroups",
          "ssm:DescribeInstancePatchStates",
          "ssm:DescribeInstancePatches",
          "ssm:DescribePatchProperties"
        ]
        Resource = "*"
      }
    ]
  })
}