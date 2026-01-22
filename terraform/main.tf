terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  # https://s3.console.aws.amazon.com/s3/object/bjoli-joe-terraform-state?region=us-west-2&prefix=main
  backend "s3" {
    bucket = "bjoli-joe-terraform-state"
    key    = "main"
    region = "us-west-2"

    # In order to "lock" the S3 object, we use a semaphore in a dynamodb table.
    # https://www.terraform.io/docs/backends/types/s3.html#dynamodb-table-permissions
    #dynamodb_table = "terraform-state"
  }

  required_version = "~>1.0.0"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}
