# modules/sqs/outputs.tf
output "queue_url" {
  value = aws_sqs_queue.translation_queue.id
}

output "queue_arn" {
  value = aws_sqs_queue.translation_queue.arn
}