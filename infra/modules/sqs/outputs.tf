# This code outputs the ARN and name of the greetings_queue SQS queue for use in other resources or for reference

output "greeting_queue_arn" {
  value = aws_sqs_queue.greeting_queue.arn
}

output "greeting_queue_name" {
  value = aws_sqs_queue.greeting_queue.name
}
