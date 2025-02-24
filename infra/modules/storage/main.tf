/*
Creates two S3 buckets with ownership control (BucketOwnerPreferred) and private access control, each tagged with the environment variable
The `private` ACL ensures that only the bucket owner has access to the objects in the bucket, providing a higher level of security by restricting public access.
This setting ensures that the bucket owner has full control over the objects, even if another AWS account uploads objects into the bucket, 
preventing permission issues related to object ownership.
*/

# Creates the source S3 bucket (src_bucket) and tags it with the environment variable.
resource "aws_s3_bucket" "src_bucket" {
  bucket = var.src_bucket_name
  tags = {
    environment = var.tag_environment
  }
}

# Configures ownership controls for the source S3 bucket to ensure the bucket owner has full control over uploaded objects.
resource "aws_s3_bucket_ownership_controls" "src_bucket_ownership_controls" {
  bucket = aws_s3_bucket.src_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Sets the access control list (ACL) of the source S3 bucket to private, ensuring only the bucket owner has access.
resource "aws_s3_bucket_acl" "src_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.src_bucket_ownership_controls]
  bucket     = aws_s3_bucket.src_bucket.id
  acl        = "private"
}

# Creates the destination S3 bucket (dst_bucket) and tags it with the environment variable.
resource "aws_s3_bucket" "dst_bucket" {
  bucket = var.dst_bucket_name

  tags = {
    environment = var.tag_environment
  }
}

# Configures ownership controls for the destination S3 bucket to ensure the bucket owner has full control over uploaded objects.
resource "aws_s3_bucket_ownership_controls" "dst_bucket_ownership_controls" {
  bucket = aws_s3_bucket.dst_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Sets the access control list (ACL) of the destination S3 bucket to private, ensuring only the bucket owner has access.
resource "aws_s3_bucket_acl" "dst_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.dst_bucket_ownership_controls]
  bucket     = aws_s3_bucket.dst_bucket.id
  acl        = "private"
}
