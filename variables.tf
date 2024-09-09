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
 default = "ledger-topic" 
}

variable "topic_name_media" {
 description = "Name of the SNS topic for media"
 default = "media-topic" 
}

variable "sqs_name_ledger" {
 description = "Name of the SQS for ledger"
 default = "ledger-queue" 
}

variable "sqs_name_dlq_ledger" {
 description = "Name of the SQS for DLQ ledger"
 default = "ledger-dlq-queue" 
}

variable "sqs_name_media_text" {
 description = "Name of the SQS for media text"
 default = "media-text-queue" 
}

variable "sqs_name_dlq_media_text" {
 description = "Name of the SQS for DLQ media-text"
 default = "media-text-dlq-queue" 
}


variable "email_address" {
 description = "Email address for SNS subscription"
 default = "ernieMakesStuff@gmail.com"
}