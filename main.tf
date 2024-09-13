# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

resource "aws_sns_topic" "ledger_topic" {
  name = "${var.topic_name_ledger}"
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
}

resource "aws_s3_bucket" "media_bucket" {
  bucket = "${var.s3_media_bucket_name}"
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "media_bucket_configuration" {
  bucket = aws_s3_bucket.media_bucket.id
  name   = "MediaBucketTiering"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}