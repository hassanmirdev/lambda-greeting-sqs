/*
This code sets up an API Gateway with a `/greet` resource to trigger an SQS queue for sending messages, using an IAM role and policy to allow access. 
It also deploys the API to a specified stage with automatic redeployment detection based on changes.
*/


# Creates an IAM role that allows API Gateway to assume it for interacting with AWS resources (specifically for sending messages to SQS).
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
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Defines a policy that grants the created IAM role permission to perform the sqs:SendMessage action on the specified SQS 
# queue (identified by greeting_queue_arn).
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

# Creates an API Gateway named greeting_api that is configured to use the REGIONAL endpoint type for handling requests.
resource "aws_api_gateway_rest_api" "greeting_api" {
  name        = "greeting_api"
  description = "API for invoking the Greeting Lambda Function"
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    environment: var.tag_environment
  }
}

# Creates the /greet resource under the greeting_api API Gateway, which will be used to handle the greeting-related requests.
resource "aws_api_gateway_resource" "greet_resource" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  parent_id   = aws_api_gateway_rest_api.greeting_api.root_resource_id
  path_part   = "greet"
}

# Defines a POST HTTP method for the /greet resource. It does not require authorization and is set up to receive requests to invoke the greeting functionality.
resource "aws_api_gateway_method" "greet_method" {
  rest_api_id   = aws_api_gateway_rest_api.greeting_api.id
  resource_id   = aws_api_gateway_resource.greet_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# These data sources retrieve the current AWS region and caller identity (AWS account ID), which are later used in the URI 
# for the API Gateway integration and to dynamically reference the AWS account
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


# Integrates the API Gateway POST method on /greet with an SQS queue to send messages using SendMessage.
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

# Defines the successful response (2xx) for the POST method, returning a "status": "success" message
resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  resource_id = aws_api_gateway_resource.greet_resource.id
  http_method = aws_api_gateway_method.greet_method.http_method
  status_code = 200
  selection_pattern = "^2[0-9][0-9]" # Any 2xx response

  response_templates = {
    "application/json" = "{\"status\": \"success\"}"
  }

  depends_on = [aws_api_gateway_integration.greet_method_integration]
}

# Configures a 200 OK response for the /greet POST method, with an empty model for JSON responses
resource "aws_api_gateway_method_response" "method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  resource_id = aws_api_gateway_resource.greet_resource.id
  http_method = aws_api_gateway_method.greet_method.http_method
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
}

# Deploys the greeting_api to a specific stage and triggers redeployment when the configuration changes, ensuring the new API version is applied.
resource "aws_api_gateway_deployment" "greeting_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  stage_name  = var.tag_environment

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.greeting_api.body))   #SHA is often used for change detection. For instance, sha256 is used to trigger redeployment of resources (such as API Gateway deployment) when the configuration has changed.


  }

  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [aws_api_gateway_method.greet_method, aws_api_gateway_integration.greet_method_integration]
}
