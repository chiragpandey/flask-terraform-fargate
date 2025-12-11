terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # registry.terraform.io/hashicorp/aws is the address of the provider in the Terraform Registry.
      version = "~> 5.92"       # version is an argument that specifies the version of the provider to use.
    }
  }

  required_version = ">= 1.2" # required_version argument is used to specify the version of Terraform that is required to use this configuration.
}

# Providers are known as binary plugins that Terraform uses to manage resources by calling your cloud provider's APIs
# provider "aws" {   
#     region = "us-east-1"
# }