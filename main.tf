# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "main"
  }
}

# Subnets
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az1
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az2
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ASG
resource "aws_security_group" "asg_sg" {
  name        = "asg_security_group"
  description = "Allow inbound HTTP traffic to ASG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_sns_topic" "ledger_topic" {
  name = "${var.topic_name_ledger}"
  policy = data.aws_iam_policy_document.s3-topic-policy.json
}

resource "aws_sns_topic" "published_topic" {
  name = "${var.topic_name_published}"
  policy = data.aws_iam_policy_document.s3-topic-policy.json
}

resource "aws_sns_topic" "media_topic" {
  name = "${var.topic_name_media}"
}

### Ledger Queues
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

### Published Queues

resource "aws_sqs_queue" "published_dlq_queue" {
  name                      = "${var.sqs_name_dlq_published}"
}

resource "aws_sqs_queue" "published_queue" {
  name                      = "${var.sqs_name_published}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.published_dlq_queue.arn
    maxReceiveCount = "${var.sqs_max_receive_count}"
  })
}

resource "aws_sns_topic_subscription" "published_to_sqs_target" {
  topic_arn = aws_sns_topic.published_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.published_queue.arn
}

data "aws_iam_policy_document" "allow_sns_to_sqs_published" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.published_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.published_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "published_queue_policy" {
  queue_url = aws_sqs_queue.published_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_published.json
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

resource "aws_sqs_queue" "media_context_dlq_queue" {
  name                      = "${var.sqs_name_dlq_media_context}"
}

resource "aws_sqs_queue" "media_context_queue" {
  name                      = "${var.sqs_name_media_context}"
  visibility_timeout_seconds = "${var.sqs_visibility_timeout}"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_context_dlq_queue.arn
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

resource "aws_sns_topic_subscription" "media_to_media_context_sqs_target" {
  topic_arn = aws_sns_topic.media_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_context_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Context\"}]}"
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

data "aws_iam_policy_document" "allow_sns_to_sqs_media_context" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.media_context_queue.arn]

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

resource "aws_sqs_queue_policy" "media_sfx_queue_policy" {
  queue_url = aws_sqs_queue.media_sfx_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_sfx.json
}

resource "aws_sqs_queue_policy" "media_music_queue_policy" {
  queue_url = aws_sqs_queue.media_music_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_music.json
}

resource "aws_sqs_queue_policy" "media_vocal_queue_policy" {
  queue_url = aws_sqs_queue.media_vocal_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_vocal.json
}

resource "aws_sqs_queue_policy" "media_context_queue_policy" {
  queue_url = aws_sqs_queue.media_context_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_context.json
}

# S3 Configurations ###############
resource "aws_s3_bucket" "media_bucket" {
  bucket = "${var.s3_media_bucket_name}"
}

resource "aws_s3_bucket_cors_configuration" "cors_s3_media" {
  bucket = aws_s3_bucket.media_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
  }
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

resource "aws_s3_bucket_ownership_controls" "media_bucket_ownership" {
  bucket = aws_s3_bucket.media_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.media_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "media_bucket_acl" {
  bucket = aws_s3_bucket.media_bucket.id
  acl    = "public-read"
  
  depends_on = [
    aws_s3_bucket_ownership_controls.media_bucket_ownership,
    aws_s3_bucket_public_access_block.block_public_access,
  ]
}

data "aws_iam_policy_document" "s3_media_bucket_policy" {
  policy_id = "s3_media_bucket_read"

  statement {
    actions = [
      "s3:GetObject"
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.media_bucket.arn}/Image*",
      "${aws_s3_bucket.media_bucket.arn}/Render*",
      "${aws_s3_bucket.media_bucket.arn}/Video*",
      "${aws_s3_bucket.media_bucket.arn}/Music*",
      "${aws_s3_bucket.media_bucket.arn}/*.jpg",
      "${aws_s3_bucket.media_bucket.arn}/*.jpeg",
      "${aws_s3_bucket.media_bucket.arn}/*.png",
      "${aws_s3_bucket.media_bucket.arn}/*.mp4"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    sid = "S3BucketPublicAccess"
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy_attach" {
  bucket = aws_s3_bucket.media_bucket.id
  policy = data.aws_iam_policy_document.s3_media_bucket_policy.json
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

# Used for dumping transitory files such as those generated by aws polly.
# ----- TMP BUCKET -----
resource "aws_s3_bucket" "tmp_bucket" {
  bucket = "${var.s3_tmp_bucket_name}"
}

resource "aws_s3_bucket_lifecycle_configuration" "tmp_bucket_lifecycle" {
  bucket = aws_s3_bucket.tmp_bucket.id

  rule {
    id = "cleanup-stale-data"

    filter {
      prefix = "*"
    }
    expiration {
      days = 1
    }
    status = "Enabled"
  }
}

# Serve SPA
resource "aws_s3_bucket" "web_bucket" {
  bucket = "${var.s3_web_bucket_name}"
}
resource "aws_s3_bucket_website_configuration" "web_bucket_config" {
  bucket = aws_s3_bucket.web_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  #routing_rule {
  #  condition {
  #    key_prefix_equals = "docs/"
  #  }
  #  redirect {
  #    replace_key_prefix_with = "documents/"
  #  }
  #}
}

resource "aws_s3_bucket_ownership_controls" "web_bucket_controls" {
  bucket = aws_s3_bucket.web_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "web_bucket_access" {
  bucket = aws_s3_bucket.web_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "web_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.web_bucket_controls,
    aws_s3_bucket_public_access_block.web_bucket_access,
  ]

  bucket = aws_s3_bucket.web_bucket.id
  acl    = "public-read"
}

# Launch Configuration for ASG
resource "aws_launch_configuration" "app_launch_config" {
  name_prefix          = "app-launch-config-"
  image_id             = "ami-0abcdef1234567890" # Replace with a valid Linux AMI ID
  instance_type        = "t2.micro" # Smallest available instance type
  security_groups      = [aws_security_group.asg_sg.id]

  # User data script to install GoLang and update Linux
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y golang
    # Add commands here to download and run your GoLang service
  EOF
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name                      = "app-asg"
  launch_configuration      = aws_launch_configuration.app_launch_config.name
  vpc_zone_identifier       = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asg_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
}

# LB Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# LB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}