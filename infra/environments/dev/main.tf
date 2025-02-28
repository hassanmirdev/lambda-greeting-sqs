module "storage" {
  source          = "../../modules/storage"
  src_bucket_name = "buckettostoreemployeeimages"
  dst_bucket_name = "buckettostoregreetingcards"
  tag_environment = var.environment
}

module "sqs" {
  source          = "../../modules/sqs"
  tag_environment = var.environment
}

module "lambdas" { 
    source = "../../modules/lambdas"
    depends_on = [ module.storage, module.sqs ]
    src_bucket_arn = module.storage.src_bucket_arn
    src_bucket_id = module.storage.src_bucket_id
    dst_bucket_arn = module.storage.dst_bucket_arn
    dst_bucket_id = module.storage.dst_bucket_id
    greeting_queue_arn = module.sqs.greeting_queue_arn
    lambda_memory_size = var.lambda_memory_size
    tag_environment = var.environment
}

module "apigateway" {
  source = "../../modules/apigateway"
  depends_on = [ module.sqs ]
  greeting_queue_name = module.sqs.greeting_queue_name
  greeting_queue_arn = module.sqs.greeting_queue_arn
  tag_environment = var.environment
}
