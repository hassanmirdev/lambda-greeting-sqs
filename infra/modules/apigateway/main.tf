# Create IAM Role for API Gateway to invoke the Greetings Queue
resource "aws_iam_role" "api_gateway_greeting_queue_role" {
  name = "api_gateway_greeting_queue_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect   = "Allow"
        Sid      = ""
      }
    ]
  })
}

# Create IAM Policy for API Gateway to invoke Greetings Queue
resource "aws_iam_role_policy" "api_gateway_greeting_queue_role_policy" {
  name = "api_gateway_greeting_queue_role_policy"
  role = aws_iam_role.api_gateway_greeting_queue_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "sqs:SendMessage",
        Effect   = "Allow",
        Resource = var.greeting_queue_arn
      }
    ]
  })
}

# Create the API Gateway
resource "aws_api_gateway_rest_api" "greeting_api" {
  name        = "greeting_api"
  description = "API for invoking the Greeting Lambda Function"
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    environment = var.tag_environment
  }
}

# Create the Greet Resource
resource "aws_api_gateway_resource" "greet_resource" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  parent_id   = aws_api_gateway_rest_api.greeting_api.root_resource_id
  path_part   = "greet"
}

# Create the Greet Method
resource "aws_api_gateway_method" "greet_method" {
  rest_api_id   = aws_api_gateway_rest_api.greeting_api.id
  resource_id   = aws_api_gateway_resource.greet_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration with SQS
resource "aws_api_gateway_integration" "greet_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.greeting_api.id
  resource_id             = aws_api_gateway_resource.greet_resource.id
  http_method             = aws_api_gateway_method.greet_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${var.greeting_queue_name}"
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
  credentials = aws_iam_role.api_gateway_greeting_queue_role.arn
}

# Create API Gateway Deployment
resource "aws_api_gateway_deployment" "greeting_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  stage_name  = var.tag_environment

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.greeting_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_method.greet_method, aws_api_gateway_integration.greet_method_integration]
}

# Create CloudWatch Log Group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api-gateway/greeting-api-logs"
  retention_in_days = 7
}

# Create IAM Role for API Gateway to write logs to CloudWatch
resource "aws_iam_role" "api_gateway_log_role" {
  name = "api_gateway_log_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect   = "Allow"
        Sid      = ""
      }
    ]
  })
}

# Create IAM Policy for API Gateway to write logs to CloudWatch
resource "aws_iam_role_policy" "api_gateway_log_policy" {
  name = "api_gateway_log_policy"
  role = aws_iam_role.api_gateway_log_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "logs:CreateLogGroup"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "logs:CreateLogStream"
        Effect   = "Allow"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/*"
      },
      {
        Action   = "logs:PutLogEvents"
        Effect   = "Allow"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/*:log-stream:*"
      }
    ]
  })
}

# Enable logging on API Gateway Stage
resource "aws_api_gateway_stage" "greeting_api_stage" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  stage_name  = var.tag_environment

  deployment_id = aws_api_gateway_deployment.greeting_api_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format          = jsonencode({
      requestId        = "$context.requestId",
      ip               = "$context.identity.sourceIp",
      userAgent        = "$context.identity.userAgent",
      status           = "$context.status",
      responseLength   = "$context.responseLength",
      latency          = "$context.latency"
    })
  }

  logging_level     = "INFO"
  data_trace_enabled = true
}
