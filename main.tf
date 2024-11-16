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
resource "aws_sns_topic_subscription" "ledger_to_sqs_target" {
  topic_arn = aws_sns_topic.ledger_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ledger_queue.arn
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

## !!!!!!!!!!!!!!!
## Media Queues ##

resource "aws_sqs_queue" "media_text_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_text}"
}

resource "aws_sqs_queue" "media_text_queue" {
  name                      = "${var.sqs_name_media_text}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_text}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_text_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_render_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_render}"
}

resource "aws_sqs_queue" "media_render_queue" {
  name                      = "${var.sqs_name_media_render}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_render}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_render_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_image_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_image}"
}

resource "aws_sqs_queue" "media_image_queue" {
  name                      = "${var.sqs_name_media_image}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_image}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_image_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_video_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_video}"
}

resource "aws_sqs_queue" "media_video_queue" {
  name                      = "${var.sqs_name_media_video}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_video}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_video_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_sfx_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_sfx}"
}

resource "aws_sqs_queue" "media_sfx_queue" {
  name                      = "${var.sqs_name_media_sfx}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_audio}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_sfx_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_music_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_music}"
}

resource "aws_sqs_queue" "media_music_queue" {
  name                      = "${var.sqs_name_media_music}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_audio}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_music_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sqs_queue" "media_vocal_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_vocal}"
}

resource "aws_sqs_queue" "media_vocal_queue" {
  name                      = "${var.sqs_name_media_vocal}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout_media_audio}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_vocal_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
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

resource "aws_sns_topic_subscription" "media_to_media_render_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_render_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Render\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_image_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_image_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Image\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_video_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_video_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Video\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_sfx_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_sfx_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Sfx\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_music_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_music_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Music\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_vocal_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_vocal_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Vocal\"}]}"
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_text" {
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

data "aws_iam_policy_document" "allow_sns_to_sqs_media_render" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_render_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_image" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_image_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_video" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_video_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_vocal" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_vocal_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_sfx" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_sfx_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

data "aws_iam_policy_document" "allow_sns_to_sqs_media_music" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_music_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "media_text_queue_policy" {
  queue_url = aws_sqs_queue.media_text_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_text.json
}

resource "aws_sqs_queue_policy" "media_render_queue_policy" {
  queue_url = aws_sqs_queue.media_render_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_render.json
}

resource "aws_sqs_queue_policy" "media_image_queue_policy" {
  queue_url = aws_sqs_queue.media_image_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_image.json
}

resource "aws_sqs_queue_policy" "media_video_queue_policy" {
  queue_url = aws_sqs_queue.media_video_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_video.json
}

resource "aws_sqs_queue_policy" "media_vocal_queue_policy" {
  queue_url = aws_sqs_queue.media_vocal_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_vocal.json
}

resource "aws_sqs_queue_policy" "media_sfx_queue_policy" {
  queue_url = aws_sqs_queue.media_sfx_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_sfx.json
}

resource "aws_sqs_queue_policy" "media_music_queue_policy" {
  queue_url = aws_sqs_queue.media_music_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_music.json
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

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.media_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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
    # Few hours access time.
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 635
  }

  tiering {
    # 5minutes to few hours access time depending on object size.
    access_tier = "ARCHIVE_ACCESS"
    days        = 455
  }
}