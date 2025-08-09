# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Provider for us-west-2 (primary region)
provider "aws" {
  alias  = "us_west_2"
  region = var.region
}

# Provider for eu-west-2 (secondary region)
provider "aws" {
  alias  = "eu_west_2"
  region = var.region_eu_west_2
}

# Default provider for backward compatibility
provider "aws" {
  region = var.region
}

# =============================================================================
# US-WEST-2 RESOURCES
# =============================================================================

# VPC - US-WEST-2
resource "aws_vpc" "main" {
  provider   = aws.us_west_2
  cidr_block = var.vpc_cidr

  tags = {
    Name = "main-us-west-2"
  }
}

# Subnets - US-WEST-2
resource "aws_subnet" "public_subnet_az1" {
  provider                = aws.us_west_2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az1
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az1-us-west-2"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  provider                = aws.us_west_2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az2
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az2-us-west-2"
  }
}

# Internet Gateway - US-WEST-2
resource "aws_internet_gateway" "main" {
  provider = aws.us_west_2
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "main-us-west-2"
  }
}

# Route Table - US-WEST-2
resource "aws_route_table" "public" {
  provider = aws.us_west_2
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-us-west-2"
  }
}

# Route Table Associations - US-WEST-2
resource "aws_route_table_association" "public_az1" {
  provider       = aws.us_west_2
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  provider       = aws.us_west_2
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ASG - US-WEST-2
resource "aws_security_group" "asg_sg" {
  provider    = aws.us_west_2
  name        = "asg_security_group"
  description = "Allow inbound HTTP traffic to ASG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allowing SSH from 0.0.0.0/0 is a security risk. Restrict this to your IP or a trusted network.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asg-sg-us-west-2"
  }
}

# Launch Template for ASG - US-WEST-2
resource "aws_launch_template" "app_launch_template" {
  provider    = aws.us_west_2
  name_prefix = "app-launch-template-us-west-2-"
  image_id    = var.ami_id_us_west_2
  instance_type = "t2.micro" # Smallest available instance type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.asg_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y golang
    # Add commands here to download and run your GoLang service
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance-us-west-2"
    }
  }
}

# Auto Scaling Group - US-WEST-2
resource "aws_autoscaling_group" "app_asg" {
  provider            = aws.us_west_2
  name                = "app-asg-us-west-2"
  vpc_zone_identifier = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  launch_template {
    id = aws_launch_template.app_launch_template.id
  }
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "app-instance-us-west-2"
    propagate_at_launch = true
  }
}

# Application Load Balancer - US-WEST-2
resource "aws_lb" "app_lb" {
  provider           = aws.us_west_2
  name               = "app-lb-us-west-2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asg_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  tags = {
    Name = "app-lb-us-west-2"
  }
}

# LB Target Group - US-WEST-2
resource "aws_lb_target_group" "app_tg" {
  provider = aws.us_west_2
  name     = "app-tg-us-west-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "app-tg-us-west-2"
  }
}

# LB Listener - US-WEST-2
resource "aws_lb_listener" "http_listener" {
  provider          = aws.us_west_2
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ASG Attachment - US-WEST-2
resource "aws_autoscaling_attachment" "app_asg_attachment" {
  provider               = aws.us_west_2
  autoscaling_group_name = aws_autoscaling_group.app_asg.id
  lb_target_group_arn    = aws_lb_target_group.app_tg.arn
}

# =============================================================================
# EU-WEST-2 RESOURCES
# =============================================================================

# VPC - EU-WEST-2
resource "aws_vpc" "main_eu" {
  provider   = aws.eu_west_2
  cidr_block = var.vpc_cidr_eu

  tags = {
    Name = "main-eu-west-2"
  }
}

# Subnets - EU-WEST-2
resource "aws_subnet" "public_subnet_az1_eu" {
  provider                = aws.eu_west_2
  vpc_id                  = aws_vpc.main_eu.id
  cidr_block              = var.public_subnet_cidr_az1_eu
  availability_zone       = "${var.region_eu_west_2}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az1-eu-west-2"
  }
}

resource "aws_subnet" "public_subnet_az2_eu" {
  provider                = aws.eu_west_2
  vpc_id                  = aws_vpc.main_eu.id
  cidr_block              = var.public_subnet_cidr_az2_eu
  availability_zone       = "${var.region_eu_west_2}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az2-eu-west-2"
  }
}

# Internet Gateway - EU-WEST-2
resource "aws_internet_gateway" "main_eu" {
  provider = aws.eu_west_2
  vpc_id   = aws_vpc.main_eu.id

  tags = {
    Name = "main-eu-west-2"
  }
}

# Route Table - EU-WEST-2
resource "aws_route_table" "public_eu" {
  provider = aws.eu_west_2
  vpc_id   = aws_vpc.main_eu.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_eu.id
  }

  tags = {
    Name = "public-eu-west-2"
  }
}

# Route Table Associations - EU-WEST-2
resource "aws_route_table_association" "public_az1_eu" {
  provider       = aws.eu_west_2
  subnet_id      = aws_subnet.public_subnet_az1_eu.id
  route_table_id = aws_route_table.public_eu.id
}

resource "aws_route_table_association" "public_az2_eu" {
  provider       = aws.eu_west_2
  subnet_id      = aws_subnet.public_subnet_az2_eu.id
  route_table_id = aws_route_table.public_eu.id
}

# Security Group for ASG - EU-WEST-2
resource "aws_security_group" "asg_sg_eu" {
  provider    = aws.eu_west_2
  name        = "asg_security_group_eu"
  description = "Allow inbound HTTP traffic to ASG"
  vpc_id      = aws_vpc.main_eu.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allowing SSH from 0.0.0.0/0 is a security risk. Restrict this to your IP or a trusted network.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asg-sg-eu-west-2"
  }
}

# Launch Template for ASG - EU-WEST-2
resource "aws_launch_template" "app_launch_template_eu" {
  provider    = aws.eu_west_2
  name_prefix = "app-launch-template-eu-west-2-"
  image_id    = var.ami_id_eu_west_2
  instance_type = "t2.micro" # Smallest available instance type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.asg_sg_eu.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y golang
    # Add commands here to download and run your GoLang service
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance-eu-west-2"
    }
  }
}

# Auto Scaling Group - EU-WEST-2
resource "aws_autoscaling_group" "app_asg_eu" {
  provider            = aws.eu_west_2
  name                = "app-asg-eu-west-2"
  vpc_zone_identifier = [aws_subnet.public_subnet_az1_eu.id, aws_subnet.public_subnet_az2_eu.id]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  launch_template {
    id = aws_launch_template.app_launch_template_eu.id
  }
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "app-instance-eu-west-2"
    propagate_at_launch = true
  }
}

# Application Load Balancer - EU-WEST-2
resource "aws_lb" "app_lb_eu" {
  provider           = aws.eu_west_2
  name               = "app-lb-eu-west-2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asg_sg_eu.id]
  subnets            = [aws_subnet.public_subnet_az1_eu.id, aws_subnet.public_subnet_az2_eu.id]

  tags = {
    Name = "app-lb-eu-west-2"
  }
}

# LB Target Group - EU-WEST-2
resource "aws_lb_target_group" "app_tg_eu" {
  provider = aws.eu_west_2
  name     = "app-tg-eu-west-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_eu.id

  tags = {
    Name = "app-tg-eu-west-2"
  }
}

# LB Listener - EU-WEST-2
resource "aws_lb_listener" "http_listener_eu" {
  provider          = aws.eu_west_2
  load_balancer_arn = aws_lb.app_lb_eu.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg_eu.arn
  }
}

# ASG Attachment - EU-WEST-2
resource "aws_autoscaling_attachment" "app_asg_attachment_eu" {
  provider               = aws.eu_west_2
  autoscaling_group_name = aws_autoscaling_group.app_asg_eu.id
  lb_target_group_arn    = aws_lb_target_group.app_tg_eu.arn
}

# =============================================================================
# SNS/SQS RESOURCES (US-WEST-2 ONLY)
# =============================================================================

resource "aws_sns_topic" "ledger_topic" {
  provider = aws.us_west_2
  name     = var.topic_name_ledger
  policy   = data.aws_iam_policy_document.s3-topic-policy.json
}

resource "aws_sns_topic" "published_topic" {
  provider = aws.us_west_2
  name     = var.topic_name_published
  policy   = data.aws_iam_policy_document.s3-topic-policy.json
}

resource "aws_sns_topic" "media_topic" {
  provider = aws.us_west_2
  name     = var.topic_name_media
}

### Ledger Queues
resource "aws_sqs_queue" "ledger_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_ledger
}

resource "aws_sqs_queue" "ledger_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_ledger
  visibility_timeout_seconds = var.sqs_visibility_timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ledger_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sns_topic_subscription" "ledger_to_sqs_target" {
  provider  = aws.us_west_2
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
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.ledger_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_ledger.json
}

### Published Queues

resource "aws_sqs_queue" "published_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_published
}

resource "aws_sqs_queue" "published_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_published
  visibility_timeout_seconds = var.sqs_visibility_timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.published_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sns_topic_subscription" "published_to_sqs_target" {
  provider  = aws.us_west_2
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
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.published_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_published.json
}

## !!!!!!!!!!!!!!!
## Media Queues ##

resource "aws_sqs_queue" "media_text_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_text
}

resource "aws_sqs_queue" "media_text_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_text
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_text
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_text_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_render_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_render
}

resource "aws_sqs_queue" "media_render_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_render
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_render
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_render_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_image_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_image
}

resource "aws_sqs_queue" "media_image_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_image
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_image
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_image_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_video_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_video
}

resource "aws_sqs_queue" "media_video_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_video
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_video
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_video_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_sfx_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_sfx
}

resource "aws_sqs_queue" "media_sfx_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_sfx
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_audio
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_sfx_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_music_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_music
}

resource "aws_sqs_queue" "media_music_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_music
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_audio
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_music_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_vocal_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_vocal
}

resource "aws_sqs_queue" "media_vocal_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_vocal
  visibility_timeout_seconds = var.sqs_visibility_timeout_media_audio
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_vocal_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue" "media_context_dlq_queue" {
  provider = aws.us_west_2
  name     = var.sqs_name_dlq_media_context
}

resource "aws_sqs_queue" "media_context_queue" {
  provider                   = aws.us_west_2
  name                       = var.sqs_name_media_context
  visibility_timeout_seconds = var.sqs_visibility_timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_context_dlq_queue.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TODO, set filter policy on media SNS-SQS subscriptions.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription#filter_policy
# https://docs.aws.amazon.com/sns/latest/dg/string-value-matching.html#string-equals-ignore
resource "aws_sns_topic_subscription" "media_to_media_text_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_text_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Text\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_render_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_render_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Render\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_image_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_image_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Image\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_video_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_video_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Video\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_sfx_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_sfx_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Sfx\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_music_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_music_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Music\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_vocal_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_vocal_queue.arn
  filter_policy = "{\"filterKey\": [{\"equals-ignore-case\": \"Vocal\"}]}"
}

resource "aws_sns_topic_subscription" "media_to_media_context_sqs_target" {
  provider      = aws.us_west_2
  topic_arn     = aws_sns_topic.media_topic.arn
  protocol      = "sqs"
  endpoint      = aws_sqs_queue.media_context_queue.arn
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
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_text_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_text.json
}

resource "aws_sqs_queue_policy" "media_render_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_render_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_render.json
}

resource "aws_sqs_queue_policy" "media_image_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_image_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_image.json
}

resource "aws_sqs_queue_policy" "media_video_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_video_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_video.json
}

resource "aws_sqs_queue_policy" "media_sfx_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_sfx_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_sfx.json
}

resource "aws_sqs_queue_policy" "media_music_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_music_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_music.json
}

resource "aws_sqs_queue_policy" "media_vocal_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_vocal_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_vocal.json
}

resource "aws_sqs_queue_policy" "media_context_queue_policy" {
  provider  = aws.us_west_2
  queue_url = aws_sqs_queue.media_context_queue.id
  policy    = data.aws_iam_policy_document.allow_sns_to_sqs_media_context.json
}

# =============================================================================
# S3 CONFIGURATIONS (US-WEST-2 ONLY)
# =============================================================================
resource "aws_s3_bucket" "media_bucket" {
  provider = aws.us_west_2
  bucket   = var.s3_media_bucket_name
}

resource "aws_s3_bucket_cors_configuration" "cors_s3_media" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id

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
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  provider                = aws.us_west_2
  bucket                  = aws_s3_bucket.media_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "media_bucket_acl" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id
  acl      = "public-read"
  
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
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id
  policy   = data.aws_iam_policy_document.s3_media_bucket_policy.json
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id

  topic {
    topic_arn = aws_sns_topic.ledger_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "media_bucket_configuration" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.media_bucket.id
  name     = "TrueVineMediaBucketTiering"

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
  provider = aws.us_west_2
  bucket   = var.s3_tmp_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "tmp_bucket_lifecycle" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.tmp_bucket.id

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
  provider = aws.us_west_2
  bucket   = var.s3_web_bucket_name
}

resource "aws_s3_bucket_website_configuration" "web_bucket_config" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.web_bucket.id

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
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.web_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "web_bucket_access" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.web_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "web_bucket_acl" {
  provider = aws.us_west_2
  depends_on = [
    aws_s3_bucket_ownership_controls.web_bucket_controls,
    aws_s3_bucket_public_access_block.web_bucket_access,
  ]

  bucket = aws_s3_bucket.web_bucket.id
  acl    = "public-read"
}