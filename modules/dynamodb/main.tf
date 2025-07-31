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
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name               = "email-index"
    hash_key           = "email"
    projection_type    = "ALL"  
    read_capacity      = 5     
    write_capacity     = 5      
  }
}

resource "aws_dynamodb_table" "api_key_metadata" {
  name         = "ApiKeyMetadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  
  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "api_key"
    type = "S"
  }


  attribute {
    name = "user_email"
    type = "S"
  }


  global_secondary_index {
    name            = "ApiKeyIndex"
    hash_key        = "api_key"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "UserEmailIndex"
    hash_key        = "user_email"
    projection_type = "ALL"
  }

 

  tags = {
    Name        = "ApiKeyMetadata"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

output "api_table_name" {
  value = aws_dynamodb_table.api_key_metadata.name
}

output "api_table_arn" {
  value = aws_dynamodb_table.api_key_metadata.arn
}


output "dynamodb_table_name" {
  value = aws_dynamodb_table.translation_metadata.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.translation_metadata.arn
}