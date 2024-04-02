terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region
}

data "archive_file" "store_payload_lambda_function" {
  type = "zip"
  source_file = "./src/store-payload-lambda-function/app.py"
  output_path = "./out/store-payload-lambda-function.zip"
}

resource "aws_iam_role" "store_payload_lambda_function" {
  name = "${var.store_payload_lambda_function_name}-lambda-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "store_payload_lambda_function" {
  name = "/aws/lambda/${var.store_payload_lambda_function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "store_payload_lambda_function_cloudwatch_access_policy" {
  name = "cloudwatch-access_policy"

  role = aws_iam_role.store_payload_lambda_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.store_payload_lambda_function.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "store_payload_lambda_function_datastore_access_policy" {
  name = "datastore-access-policy"

  role = aws_iam_role.store_payload_lambda_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.datastore.arn
      }
    ]
  })
}

resource "aws_lambda_function" "store_payload_lambda_function" {
  function_name = var.store_payload_lambda_function_name

  architectures = [ "arm64" ]

  runtime = "python3.9"
  role = aws_iam_role.store_payload_lambda_function.arn

  source_code_hash = data.archive_file.store_payload_lambda_function.output_base64sha256
  filename         = "./out/store-payload-lambda-function.zip"
  handler          = "app.lambda_handler"
  
  environment {
    variables = {
      DATASTORE_TABLE_NAME = aws_dynamodb_table.datastore.id,
      TOTAL_COUNT_ITEM_KEY = var.datastore_total_count_item_key
    }
  }

  depends_on = [ aws_cloudwatch_log_group.store_payload_lambda_function ]
}

resource "aws_lambda_function_url" "store_payload_lambda_function" {
  function_name = aws_lambda_function.store_payload_lambda_function.function_name
  authorization_type = "NONE"
}

data "archive_file" "generate_report_lambda_function" {
  type        = "zip"
  source_file = "./src/generate-report-lambda-function/app.py"
  output_path = "./out/generate-report-lambda-function.zip"
}

resource "aws_iam_role" "generate_report_lambda_function" {
  name = "${var.generate_report_lambda_function_name}-lambda-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "generate_report_lambda_function" {
  name              = "/aws/lambda/${var.generate_report_lambda_function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "generate_report_lambda_function_cloudwatch_access_policy" {
  name = "cloudwatch-access-policy"

  role = aws_iam_role.generate_report_lambda_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.generate_report_lambda_function.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "generate_report_lambda_function_datastore_access_policy" {
  name = "datastore-access-policy"

  role = aws_iam_role.generate_report_lambda_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.datastore.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "generate_report_lambda_function_s3_access_policy" {
  name = "s3-access-policy"

  role = aws_iam_role.generate_report_lambda_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.report_bucket_name}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "generate_report_lambda_function" {
  function_name = var.generate_report_lambda_function_name

  architectures = [
    "arm64"
  ]

  runtime = "python3.9"
  role    = aws_iam_role.generate_report_lambda_function.arn

  source_code_hash = data.archive_file.generate_report_lambda_function.output_base64sha256
  filename         = "./out/generate-report-lambda-function.zip"
  handler          = "app.lambda_handler"

  environment {
    variables = {
      REPORT_BUCKET_NAME   = var.report_bucket_name
      DATASTORE_TABLE_NAME = aws_dynamodb_table.datastore.id,
      TOTAL_COUNT_ITEM_KEY = var.datastore_total_count_item_key
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.generate_report_lambda_function
  ]
}

resource "aws_cloudwatch_event_rule" "generate_report_lambda_function" {
  name = var.generate_report_lambda_function_name

  schedule_expression = var.generate_report_lambda_function_schedule
}

resource "aws_cloudwatch_event_target" "generate_report_lambda_function" {
  target_id = var.generate_report_lambda_function_name

  rule = aws_cloudwatch_event_rule.generate_report_lambda_function.name
  arn  = aws_lambda_function.generate_report_lambda_function.arn
}

resource "aws_lambda_permission" "generate_report_lambda_function" {
  statement_id  = "AllowScheduledExecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report_lambda_function.function_name
  principal     = "events.amazonaws.com"
}


# database

resource "aws_dynamodb_table" "datastore" {
  name = var.datastore_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "PK"

  attribute {
    name = "PK"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "datastore_total_count_item" {
  table_name = aws_dynamodb_table.datastore.name
  hash_key = aws_dynamodb_table.datastore.hash_key

  item = jsonencode({
    PK = {
      S = var.datastore_total_count_item_key
    },
    value = {
      N = "0"
    }
  })

  lifecycle {
    ignore_changes = [ item ]
  }
}

#report bucket

resource "aws_s3_bucket" "report_bucket" {
  count = var.report_bucket_exists ? 0 : 1

  bucket = var.report_bucket_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "report_bucket" {
  count = var.report_bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.report_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "report_bucket" {
  count = var.report_bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.report_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}