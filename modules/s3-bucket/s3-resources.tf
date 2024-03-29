resource "aws_s3_bucket" "access_log" {
  bucket        = var.log_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "access-log" {
  bucket = aws_s3_bucket.access_log.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "access_log" {
  depends_on = [aws_s3_bucket_ownership_controls.access-log]
  bucket = aws_s3_bucket.access_log.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_log" {
  count = var.lifecycle_glacier_transition_days > 0 ? 1 : 0

  bucket = aws_s3_bucket.access_log.id

  rule {
    id     = "auto-archive"
    status = "Enabled"

    filter {}

    transition {
      days          = var.lifecycle_glacier_transition_days
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_policy" "access_log_policy" {
  bucket = aws_s3_bucket.access_log.id
  policy = data.aws_iam_policy_document.access_log_policy.json

  depends_on = [aws_s3_bucket_public_access_block.access_log]
}

resource "aws_s3_bucket_public_access_block" "access_log" {
  bucket                  = aws_s3_bucket.access_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "content" {
  bucket_prefix = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
  depends_on    = [aws_s3_bucket_public_access_block.access_log]
}

resource "aws_s3_bucket_ownership_controls" "content" {
  bucket = aws_s3_bucket.content.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "content" {
  depends_on = [aws_s3_bucket_ownership_controls.content]
  bucket = aws_s3_bucket.content.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

resource "aws_s3_bucket_logging" "content" {
  bucket        = aws_s3_bucket.content.id
  target_bucket = aws_s3_bucket.access_log.id
  target_prefix = ""
}

resource "aws_s3_bucket_lifecycle_configuration" "content" {
  count = var.lifecycle_glacier_transition_days > 0 ? 1 : 0

  bucket = aws_s3_bucket.content.id

  rule {
    id     = "auto-archive"
    status = "Enabled"

    filter {}

    transition {
      days          = var.lifecycle_glacier_transition_days
      storage_class = "INTELLIGENT_TIERING"
    }

    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_glacier_transition_days
      storage_class   = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket                  = aws_s3_bucket.content.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sns_topic" "topic" {
  name              = "${aws_s3_bucket.content.id}-notification-topic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_s3_bucket_notification" "content_bucket_notification" {
  bucket = aws_s3_bucket.content.id

  topic {
    topic_arn = aws_sns_topic.topic.arn
    events    = ["s3:ObjectRemoved:*"]
  }
  depends_on = [ aws_sns_topic_policy.topic_policy ]
}

resource "aws_sns_topic_policy" "topic_policy" {
  arn    = aws_sns_topic.topic.arn
  policy = data.aws_iam_policy_document.topic_policy_document.json
}

resource "aws_s3_bucket_notification" "access_log_bucket_notification" {
  bucket = aws_s3_bucket.access_log.id

  topic {
    topic_arn = aws_sns_topic.topic.arn
    events    = ["s3:ObjectRemoved:*"]
  }
  depends_on = [ aws_sns_topic_policy.topic_policy ]
}

resource "aws_sns_topic_subscription" "notification_subscription" {
  protocol  = "email"
  endpoint  = var.sns_endpoint
  topic_arn = aws_sns_topic.topic.arn
}
