variable "environment" {
  type = string
  description = "define environment variable"
  default = "production"
}

variable "lambda_memory_size" {
  description = "define lambda memory size"
  type = number
  default = 1024
}
