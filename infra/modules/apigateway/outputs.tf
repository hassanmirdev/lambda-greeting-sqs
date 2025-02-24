# This outputs the full endpoint URL for the deployed greeting_api API Gateway, appending /greet to the invoke URL.

output "greeting_api_endpoint" {
  value = "${aws_api_gateway_deployment.greeting_api_deployment.invoke_url}/greet"
}
