terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
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

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.todo_table.arn
      },
      {
        Action   = "logs:*",
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
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

#FOR CORS BECAUSE ITS ANNOYING
resource "aws_api_gateway_method" "cors_options" {
    rest_api_id = aws_api_gateway_rest_api.student_api.id
    resource_id = aws_api_gateway_resource.student_resource.id
    http_method = "OPTIONS"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  resource_id = aws_api_gateway_resource.student_resource.id
  http_method = aws_api_gateway_method.cors_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  resource_id = aws_api_gateway_resource.student_resource.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  resource_id = aws_api_gateway_resource.student_resource.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
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
}


resource "aws_lambda_permission" "apigw_lambdapost" {
  statement_id  = "AllowExecutionFromAPIGatewayPOST"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func_2.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.student_api.id}/*/${aws_api_gateway_method.post_student_method.http_method}${aws_api_gateway_resource.student_resource.path}"
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.student_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_method.get_student_method, aws_api_gateway_method.post_student_method, aws_api_gateway_integration.getIntegration, aws_api_gateway_integration.postIntegration, aws_api_gateway_integration.cors_integration]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  stage_name    = "prod"
}


# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "hrishin-test-111"
  website {
    index_document = "index.html"
  }
}

# Upload index.html file to S3
resource "aws_s3_bucket_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.bucket
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}

# Upload scripts.js file to S3
resource "aws_s3_bucket_object" "scripts_js" {
  bucket       = aws_s3_bucket.frontend_bucket.bucket
  key          = "scripts.js"
  source       = "scripts.js"
  content_type = "application/javascript"
}

output "frontend_url" {
  value = aws_s3_bucket.frontend_bucket.website_endpoint
}