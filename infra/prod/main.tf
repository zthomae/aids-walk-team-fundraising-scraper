variable "region" {
  description = "The AWS region that the infrastructure will be deployed in"
  type = string
  default = "us-east-2"
}

variable "environment" {
  description = "The name of this deployment instance"
  type = string
}

provider "aws" {
  region = var.region
}

module "personalized_standings" {
  source = "../modules/personalized_standings"
  environment = var.environment
}
