# modules/iam/main.tf
resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.prefix}-lambda-s3-access"
  description = "Policy for Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${var.input_bucket_arn}",
          "${var.input_bucket_arn}/*",
          "${var.output_bucket_arn}",
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Effect : "Allow",
        Action : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource : var.sqs_queue_arn
      },
      {
        Effect = "Allow",
        Action = [
          "translate:TranslateText",
          "comprehend:DetectDominantLanguage"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_sqs_access" {
  name        = "${var.prefix}-lambda-sqs-access"
  description = "Policy for Lambda to access SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = [
          var.sqs_queue_arn
        ]
      }
    ]
  })
}
resource "aws_iam_policy" "lambda_dynamodb_access" {
  name        = "${var.prefix}-lambda-dynamodb-access"
  description = "Policy for Lambda to get and put items in DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}
resource "aws_iam_policy" "translate_access" {
  name        = "${var.prefix}-translate-access"
  description = "Policy for Lambda to access Amazon Translate"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "translate:TranslateText"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_access.arn
}

resource "aws_iam_role_policy_attachment" "translate_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.translate_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_access.arn
}