# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "regionalternate" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "topic_name_ledger" {
 description = "Name of the SNS topic for ledger"
 default = "state-callback-topic" 
}

variable "topic_name_media" {
 description = "Name of the SNS topic for media"
 default = "media-topic" 
}

variable "sqs_visibility_timeout" {
 description = "Visibility timeout seconds"
 default = 180
}

variable "sqs_visibility_timeout_media_text" {
 description = "Visibility timeout seconds for media text queues"
 default = 180
}

# TODO: Adjust this based on actual metrics for render times.
variable "sqs_visibility_timeout_media_visual" {
 description = "Visibility timeout seconds for media visual queues"
 default = 3600
}

variable "sqs_max_receive_count" {
 description = "Max times to recycle a message before putting onto DLQ"
 default = 45
}

variable "sqs_name_ledger" {
 description = "Name of the SQS for ledger"
 default = "state-callback-queue" 
}

variable "sqs_name_dlq_ledger" {
 description = "Name of the SQS for DLQ ledger"
 default = "state-callback-dlq-queue" 
}

variable "sqs_name_media_text" {
 description = "Name of the SQS for media text"
 default = "media-text-queue" 
}

variable "sqs_name_dlq_media_text" {
 description = "Name of the SQS for DLQ media-text"
 default = "media-text-dlq-queue" 
}


variable "sqs_name_media_render" {
 description = "Name of the SQS for media render"
 default = "media-render-queue" 
}

variable "sqs_name_dlq_media_render" {
 description = "Name of the SQS for DLQ render"
 default = "media-render-dlq-queue" 
}

variable "s3_media_bucket_name" {
 description = "Name for the S3 bucket that stores generated media."
 default = "truevine-media-storage" 
}