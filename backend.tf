terraform {
  backend "s3" {
    bucket = "flask-terraform-fargate-bucket-manual" # my manually created bucket
    key    = "network/terraform.tfstate"             # logical path inside S3 bucket, "path/to/terraform.tfstate"
    region = "us-east-1"                             # region of the S3 bucket
    dynamodb_table = "flask-terraform-fargate-db" # my manually created DynamoDB table
  }
}