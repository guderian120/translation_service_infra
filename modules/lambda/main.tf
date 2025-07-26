locals {
  lambda_functions = {
    translation_get_all_files  = "${path.root}/lambda_functions/translation_get_all_files"
    translation_put_file       = "${path.root}/lambda_functions/translation_upload_handler"
    translation_process_event  = "${path.root}/lambda_functions/translation_processor"
  }
}

data "archive_file" "lambda_zip" {
  for_each    = local.lambda_functions
  type        = "zip"
  source_dir  = each.value
  output_path = "${path.module}/builds/${each.key}.zip"
}

resource "aws_lambda_function" "lambda" {
  for_each = data.archive_file.lambda_zip

  function_name = each.key
  role          = var.iam_role
  handler       = "main.lambda_handler"         
  runtime       = "python3.11"          
  timeout = 120
  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_queue_url
      OUTPUT_BUCKET = var.output_bucket_name
      INPUT_BUCKET = var.input_bucket_name
      METADATA_TABLE = var.dynamodb_table_name
    }
  }
  filename         = each.value.output_path
  source_code_hash = each.value.output_base64sha256
}
