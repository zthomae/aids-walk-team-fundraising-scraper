variable "region" {
  description = "The AWS region that the infrastructure will be deployed in"
  type = string
  default = "us-east-2"
}

variable "environment" {
  description = "The name of this deployment instance"
  type = string
}

variable "local_timezone" {
  description = "The name of the timezone to localize display times for"
  type = string
  default = "America/Chicago"
}

variable "email_sender" {
  description = "The email address where messages should originate from"
  type = string
}

variable "email_recipient" {
  description = "The email address where messages should be sent"
  type = string
}

provider "aws" {
  region = var.region
}

module "personalized_standings" {
  source = "../modules/personalized_standings"
  environment = var.environment
  region = var.region
  local_timezone = var.local_timezone
  email_sender = var.email_sender
  email_recipient = var.email_recipient
}
