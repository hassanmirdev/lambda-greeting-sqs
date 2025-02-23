terraform {
  backend "s3" {
    bucket         = "nsh-terraform-demo-bucket"  
    key            = "lambda-greeting-sqs/terraform.tfstate"
    region         = "us-east-1"            
    encrypt        = true
  }
}
