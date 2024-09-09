# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "sns_ledger_topic_arn" {
  value = "${aws_sns_topic.ledger_topic}"
}

output "sns_media_topic_arn" {
  value = "${aws_sns_topic.media_topic}"
}