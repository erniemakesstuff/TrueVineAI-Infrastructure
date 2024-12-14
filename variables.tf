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
variable "sqs_visibility_timeout_media_render" {
 description = "Visibility timeout seconds for media render queues"
 default = 2700
}

variable "sqs_visibility_timeout_media_image" {
 description = "Visibility timeout seconds for media image queues"
 default = 600
}

variable "sqs_visibility_timeout_media_video" {
 description = "Visibility timeout seconds for media video queues"
 default = 1800
}

variable "sqs_visibility_timeout_media_audio" {
 description = "Visibility timeout seconds for media audio queues"
 default = 600
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

variable "sqs_name_media_image" {
 description = "Name of the SQS for media image"
 default = "media-image-queue" 
}

variable "sqs_name_dlq_media_image" {
 description = "Name of the SQS for DLQ image"
 default = "media-image-dlq-queue" 
}

variable "sqs_name_media_video" {
 description = "Name of the SQS for media video"
 default = "media-video-queue" 
}

variable "sqs_name_dlq_media_video" {
 description = "Name of the SQS for DLQ video"
 default = "media-video-dlq-queue" 
}

variable "sqs_name_media_sfx" {
 description = "Name of the SQS for media sound effects"
 default = "media-sfx-queue" 
}

variable "sqs_name_dlq_media_sfx" {
 description = "Name of the SQS for DLQ sound effects"
 default = "media-sfx-dlq-queue" 
}

variable "sqs_name_media_music" {
 description = "Name of the SQS for media music"
 default = "media-music-queue" 
}

variable "sqs_name_dlq_media_music" {
 description = "Name of the SQS for DLQ music"
 default = "media-music-dlq-queue" 
}

variable "sqs_name_media_vocal" {
 description = "Name of the SQS for media vocal"
 default = "media-vocal-queue" 
}

variable "sqs_name_dlq_media_vocal" {
 description = "Name of the SQS for DLQ vocal"
 default = "media-vocal-dlq-queue" 
}

variable "s3_media_bucket_name" {
 description = "Name for the S3 bucket that stores generated media."
 default = "truevine-media-storage" 
}

variable "s3_tmp_bucket_name" {
 description = "Name for the S3 bucket that stores transitory files."
 default = "truevine-tmp-storage"
}

variable "s3_web_bucket_name" {
 description = "Name for the S3 bucket that serves SPA."
 default = "kherem.com"
}