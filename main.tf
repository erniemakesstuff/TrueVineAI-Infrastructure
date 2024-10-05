# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

resource "aws_sns_topic" "ledger_topic" {
  name = "${var.topic_name_ledger}"
  policy = data.aws_iam_policy_document.s3-topic-policy.json
}

resource "aws_sns_topic" "media_topic" {
  name = "${var.topic_name_media}"
}

resource "aws_sqs_queue" "ledger_dlq_queue" {
  name                      = "${var.sqs_name_dlq_ledger}"
}

resource "aws_sqs_queue" "ledger_queue" {
  name                      = "${var.sqs_name_ledger}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ledger_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_text_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_text}"
}

resource "aws_sqs_queue" "media_text_queue" {
  name                      = "${var.sqs_name_media_text}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_text_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sns_topic_subscription" "ledger_to_sqs_target" {
  topic_arn = aws_sns_topic.ledger_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ledger_queue.arn
}
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TODO, set filter policy on media SNS-SQS subscriptions.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription#filter_policy
# https://docs.aws.amazon.com/sns/latest/dg/string-value-matching.html#string-equals-ignore
resource "aws_sns_topic_subscription" "media_to_media_text_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_text_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Text\"}]}"
}

data "aws_iam_policy_document" "allow_sns_to_sqs_ledger" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ledger_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.ledger_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "ledger_queue_policy" {
  queue_url = aws_sqs_queue.ledger_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_ledger.json
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_text_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "media_text_queue_policy" {
  queue_url = aws_sqs_queue.media_text_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media.json
}

# S3 Configurations ###############
resource "aws_s3_bucket" "media_bucket" {
  bucket = "${var.s3_media_bucket_name}"
}

data "aws_iam_policy_document" "s3-topic-policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:${var.topic_name_ledger}"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.media_bucket.arn]
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.media_bucket.id

  topic {
    topic_arn     = aws_sns_topic.ledger_topic.arn
    events        = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "media_bucket_configuration" {
  bucket = aws_s3_bucket.media_bucket.id
  name   = "TrueVineMediaBucketTiering"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}