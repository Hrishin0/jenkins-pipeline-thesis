terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# DynamoDB Table for To-Do Items
resource "aws_dynamodb_table" "todo_table" {
  name           = "Student"
  hash_key       = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5


  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Function 1 (GET request handler)
resource "aws_lambda_function" "lambda_func_1" {
  function_name = var.lambda_function_name
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  handler       = "getStudent.lambda_handler"
  filename      = "getStudent.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.todo_table.name
    }
  }
}

# Lambda Function 2 (POST request handler)
resource "aws_lambda_function" "lambda_func_2" {
  function_name = "insertStudent"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  handler       = "insertStudent.lambda_handler"
  filename      = "insertStudent.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.todo_table.name
    }
  }
}


#IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = <<EOF
     {
        "Version" : "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
}

# IAM Policy for Lambda Role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamodb_and_logs_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # DynamoDB permissions
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.todo_table.arn
      },
      
      # CloudWatch Logs permissions
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.myregion}:${var.accountId}:log-group:/aws/lambda/*"
      },

      # Lambda invocation permissions (for other Lambda functions if needed)
      {
        Action   = "lambda:InvokeFunction",
        Effect   = "Allow",
        Resource = "arn:aws:lambda:${var.myregion}:${var.accountId}:function:*"
      }
    ]
  })
}

#creating api
resource "aws_api_gateway_rest_api" "student_api" {
  name = "StudentAPI"
}

resource "aws_api_gateway_resource" "student_resource" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  parent_id   = aws_api_gateway_rest_api.student_api.root_resource_id
  path_part   = "students"
}

# API Methods
resource "aws_api_gateway_method" "get_student_method" {
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  resource_id   = aws_api_gateway_resource.student_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_student_method" {
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  resource_id   = aws_api_gateway_resource.student_resource.id
  http_method   = "POST"
  authorization = "NONE"
}


#No more CORS

#Integration to integrate APIgateway with Lambda 
resource "aws_api_gateway_integration" "getIntegration" {
  rest_api_id             = aws_api_gateway_rest_api.student_api.id
  resource_id             = aws_api_gateway_resource.student_resource.id
  http_method             = aws_api_gateway_method.get_student_method.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_func_1.invoke_arn
}

resource "aws_api_gateway_integration" "postIntegration" {
  rest_api_id             = aws_api_gateway_rest_api.student_api.id
  resource_id             = aws_api_gateway_resource.student_resource.id
  http_method             = aws_api_gateway_method.post_student_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_func_2.invoke_arn
}

#Allow api gateway to invoke lambda 
resource "aws_lambda_permission" "apigw_lambdaget" {
  statement_id  = "AllowExecutionFromAPIGatewayGET"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func_1.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.student_api.id}/*/${aws_api_gateway_method.get_student_method.http_method}${aws_api_gateway_resource.student_resource.path}"

  depends_on = [
    aws_api_gateway_rest_api.student_api,
    aws_api_gateway_method.get_student_method
  ]  

}


resource "aws_lambda_permission" "apigw_lambdapost" {
  statement_id  = "AllowExecutionFromAPIGatewayPOST"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func_2.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.student_api.id}/*/${aws_api_gateway_method.post_student_method.http_method}${aws_api_gateway_resource.student_resource.path}"
  depends_on = [
    aws_api_gateway_rest_api.student_api,
    aws_api_gateway_method.post_student_method
  ] 
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.student_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_method.get_student_method, aws_api_gateway_method.post_student_method, aws_api_gateway_integration.getIntegration, aws_api_gateway_integration.postIntegration]
}



resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  stage_name    = "prod"
}


module "api_gateway_enable_cors" {
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id = aws_api_gateway_rest_api.student_api.id
  api_resource_id = aws_api_gateway_resource.student_resource.id
}


# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "hrishin-test-111"
  website {
    index_document = "index.html"
  }
   cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
    # Enable server-side encryption with AES256
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Upload index.html file to S3
resource "aws_s3_bucket_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.bucket
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Stmt1733764956969",
        Effect    = "Allow",
        Principal = "*",
        Action    = [
          "s3:GetObject"
        ],
        Resource  = "arn:aws:s3:::hrishin-test-111/*"
      }
    ]
  })
  depends_on = [
    aws_s3_bucket_public_access_block.frontend_bucket_public_access
  ]
}

output "frontend_url" {
  value = aws_s3_bucket.frontend_bucket.website_endpoint
}