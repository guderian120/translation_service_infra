
resource "aws_api_gateway_rest_api" "translation_api" {
  name        = "${var.prefix}-translation-api"
  description = "API for CSV file upload to S3"
}

resource "aws_api_gateway_resource" "upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "upload"
}

# Add filename as a path parameter
resource "aws_api_gateway_resource" "filename_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_resource.upload_resource.id
  path_part   = "{filename}"
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.prefix}-cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  provider_arns = [var.cognito_user_pool_arn]
}

resource "aws_api_gateway_method" "upload_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.filename_resource.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.filename" = true
  }
}

resource "aws_api_gateway_integration" "upload_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.filename_resource.id
  http_method             = aws_api_gateway_method.upload_method.http_method
  type                    = "AWS"
  integration_http_method = "PUT"
  credentials             = aws_iam_role.api_gateway_s3.arn
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/${var.input_bucket_name}/{filename}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.filename" = "method.request.path.filename"
  }
}

# CORS Configuration
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.filename_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.filename_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.filename_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.filename_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'PUT,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_integration]
}

# Add CORS headers to the main PUT method
resource "aws_api_gateway_method_response" "upload_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.filename_resource.id
  http_method = aws_api_gateway_method.upload_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "upload_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.filename_resource.id
  http_method = aws_api_gateway_method.upload_method.http_method
  status_code = aws_api_gateway_method_response.upload_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_rest_api.translation_api, aws_api_gateway_integration.upload_integration]
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id

  triggers = {
    redeploy = timestamp()
  }

  depends_on = [
    aws_api_gateway_integration.upload_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_integration.list_files_integration,
    aws_api_gateway_integration.files_options_integration,
    aws_api_gateway_integration.api_upload_integration,
    aws_api_gateway_integration.api_upload_options_integration
  ]
}


resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}





















resource "aws_api_gateway_resource" "list_files_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "files"
}


resource "aws_api_gateway_method" "list_files_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.list_files_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "list_files_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.list_files_resource.id
  http_method             = aws_api_gateway_method.list_files_method.http_method
  type                    = "AWS"
  integration_http_method = "GET"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/${var.output_bucket_name}"
  credentials             = aws_iam_role.api_gateway_s3.arn
  passthrough_behavior    = "WHEN_NO_MATCH"

 
}

resource "aws_api_gateway_method_response" "list_files_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.list_files_resource.id
  http_method = aws_api_gateway_method.list_files_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
   depends_on = [
    aws_api_gateway_integration.list_files_integration
  ]
}


resource "aws_api_gateway_integration_response" "list_files_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.list_files_resource.id
  http_method = aws_api_gateway_method.list_files_method.http_method
  status_code = aws_api_gateway_method_response.list_files_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [
    aws_api_gateway_integration.list_files_integration
  ]
}




# CORS CONFIGS
resource "aws_api_gateway_method" "files_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.list_files_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}


resource "aws_api_gateway_integration" "files_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.list_files_resource.id
  http_method = aws_api_gateway_method.files_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}


resource "aws_api_gateway_method_response" "files_options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.list_files_resource.id
  http_method = aws_api_gateway_method.files_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}



resource "aws_api_gateway_integration_response" "files_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.list_files_resource.id
  http_method = aws_api_gateway_method.files_options_method.http_method
  status_code = aws_api_gateway_method_response.files_options_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.files_options_integration]
}












# New resource for the api_upload path
resource "aws_api_gateway_resource" "api_upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "api_upload"
}

# Method for the api_upload resource (POST is common for Lambda triggers)
resource "aws_api_gateway_method" "api_upload_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.api_upload_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Integration with Lambda function
resource "aws_api_gateway_integration" "api_upload_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.api_upload_resource.id
  http_method             = aws_api_gateway_method.api_upload_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_upload_function_invoke_arn
  
  # AWS_PROXY integrations don't need these:
  # passthrough_behavior    = "WHEN_NO_MATCH"
  # credentials             = aws_iam_role.api_gateway_s3.arn
}
resource "aws_lambda_permission" "api_gateway_upload_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_upload_function_name  # Make sure this matches your Lambda's name
  principal     = "apigateway.amazonaws.com"

  # Grant permission only to this specific API Gateway
  source_arn = "${aws_api_gateway_rest_api.translation_api.execution_arn}/*/${aws_api_gateway_method.api_upload_method.http_method}${aws_api_gateway_resource.api_upload_resource.path}"
}
# Method response
resource "aws_api_gateway_method_response" "api_upload_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.api_upload_resource.id
  http_method = aws_api_gateway_method.api_upload_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# CORS configuration
resource "aws_api_gateway_method" "api_upload_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.api_upload_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_upload_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.api_upload_resource.id
  http_method = aws_api_gateway_method.api_upload_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "api_upload_options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.api_upload_resource.id
  http_method = aws_api_gateway_method.api_upload_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "api_upload_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.api_upload_resource.id
  http_method = aws_api_gateway_method.api_upload_options_method.http_method
  status_code = aws_api_gateway_method_response.api_upload_options_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.api_upload_options_integration]
}



# IAM Role for API Gateway to access S3
resource "aws_iam_role" "api_gateway_s3" {
  name = "${var.prefix}-api-gateway-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_s3_policy" {
  name = "${var.prefix}-api-gateway-s3-policy"
  role = aws_iam_role.api_gateway_s3.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
        ],
        Resource = [
          "arn:aws:s3:::${var.input_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::${var.output_bucket_name}"
      }
    ]
  })
}



