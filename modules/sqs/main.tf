# modules/sqs/main.tf
resource "aws_sqs_queue" "translation_queue" {
  name                      = "${var.prefix}-translation-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  visibility_timeout_seconds = 720
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue_policy" "translation_queue_policy" {
  queue_url = aws_sqs_queue.translation_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = aws_sqs_queue.translation_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.lambda_translate_processor_arn
          }
        }
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.translation_queue.arn
  function_name    = var.lambda_translate_processor_arn
  batch_size       = 10
  enabled          = true
}