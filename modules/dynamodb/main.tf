# modules/dynamodb/main.tf
resource "aws_dynamodb_table" "translation_metadata" {
  name         = "TranslationMetadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "file_id"
  range_key    = "timestamp"

  attribute {
    name = "file_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    projection_type = "ALL"
  }
}



output "dynamodb_table_name" {
  value = aws_dynamodb_table.translation_metadata.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.translation_metadata.arn
}