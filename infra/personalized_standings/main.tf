variable "environment" {
  description = "The name of this deployment instance"
  type = string
}

locals {
  package_path = "${path.module}/../../build/package.zip"
}

resource "aws_iam_role" "iam_for_get_standings_data_lambda" {
  name = "iam_for_get_standings_data_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "get_standings_data_lambda_function" {
  filename = local.package_path
  function_name = "${var.environment}-get-standings-data"
  handler = "personalized_standings.get_standings_data"
  role = aws_iam_role.iam_for_get_standings_data_lambda.arn
  runtime = "python3.8"
  timeout = 30
}

resource "aws_iam_role" "iam_for_personalized_standings_lambda" {
  name = "iam_for_personalized_standings_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "personalized_standings_lambda_function" {
  filename = local.package_path
  function_name = "${var.environment}-personalized-standings"
  handler = "personalized_standings.personalized_standings"
  role = aws_iam_role.iam_for_personalized_standings_lambda.arn
  runtime = "python3.8"
  timeout = 30
}
