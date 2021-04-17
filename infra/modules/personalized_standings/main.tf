variable "region" {
  description = "The AWS region that the infrastructure will be deployed in"
  type = string
}

variable "environment" {
  description = "The name of this deployment instance"
  type = string
}

data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  package_path = "${path.module}/../../../build/package.zip"
  source_code_hash = filebase64sha256(local.package_path)
}

resource "aws_iam_role" "iam_for_get_standings_data_lambda" {
  name = "iam_for_get_standings_data_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_lambda_function" "get_standings_data_lambda_function" {
  filename = local.package_path
  source_code_hash = local.source_code_hash
  function_name = "${var.environment}-get-standings-data"
  handler = "personalized_standings.get_standings_data"
  role = aws_iam_role.iam_for_get_standings_data_lambda.arn
  runtime = "python3.8"
  timeout = 30
}

resource "aws_iam_policy" "get_standings_data_policies" {
  name = "get_standings_data_policies"
  description = "IAM policy for the get standings data lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${local.aws_account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_standings_data_attachment" {
  role = aws_iam_role.iam_for_get_standings_data_lambda.name
  policy_arn = aws_iam_policy.get_standings_data_policies.arn
}

resource "aws_dynamodb_table" "standings_table" {
  name = "${var.environment}-aids-walk-team-standings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "team_id"
  range_key = "name"
  attribute {
    name = "team_id"
    type = "S"
  }
  attribute {
    name = "name"
    type = "S"
  }
}

resource "aws_iam_role" "iam_for_store_standings_data_lambda" {
  name = "iam_for_store_standings_data_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_lambda_function" "store_standings_data_lambda_function" {
  filename = local.package_path
  source_code_hash = local.source_code_hash
  function_name = "${var.environment}-store-standings-data"
  handler = "personalized_standings.store_standings_data"
  role = aws_iam_role.iam_for_store_standings_data_lambda.arn
  runtime = "python3.8"
  timeout = 30
  environment {
    variables = {
      SCORE_TABLE_NAME = aws_dynamodb_table.standings_table.name
    }
  }
}

resource "aws_iam_policy" "store_standings_data_policies" {
  name = "store_standings_data_policies"
  description = "IAM policy for the store standings data lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["dynamodb:BatchWriteItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.standings_table.arn
      },
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${local.aws_account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "store_standings_data_attachment" {
  role = aws_iam_role.iam_for_store_standings_data_lambda.name
  policy_arn = aws_iam_policy.store_standings_data_policies.arn
}

resource "aws_iam_role" "iam_for_personalized_standings_lambda" {
  name = "iam_for_personalized_standings_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_lambda_function" "personalized_standings_lambda_function" {
  filename = local.package_path
  source_code_hash = local.source_code_hash
  function_name = "${var.environment}-personalized-standings"
  handler = "personalized_standings.personalized_standings"
  role = aws_iam_role.iam_for_personalized_standings_lambda.arn
  runtime = "python3.8"
  timeout = 30
  environment {
    variables = {
      TEMPLATE_PATH = "templates"
    }
  }
}

resource "aws_iam_policy" "personalized_standings_policies" {
  name = "personalized_standings_policies"
  description = "IAM policy for the personalized standings lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${local.aws_account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "personalized_standings_attachment" {
  role = aws_iam_role.iam_for_personalized_standings_lambda.name
  policy_arn = aws_iam_policy.personalized_standings_policies.arn
}

resource "aws_iam_role" "iam_for_update_personalized_standings_state_machine" {
  name = "iam_for_update_personalized_standings_state_machine"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
  inline_policy {
    name = "StatesExecutionPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "lambda:InvokeFunction"
          ]
          Effect = "Allow"
          Resource = [
            aws_lambda_function.get_standings_data_lambda_function.arn,
            aws_lambda_function.store_standings_data_lambda_function.arn,
            aws_lambda_function.personalized_standings_lambda_function.arn
          ]
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "update_personalized_standings_state_machine" {
  name = "${var.environment}-update-personalized-standings"
  role_arn = aws_iam_role.iam_for_update_personalized_standings_state_machine.arn
  definition = jsonencode({
    Comment = "Updates and returns personalized standings information for a given team/participant"
    StartAt = "GetStandingsData"
    States = {
      GetStandingsData = {
        Type = "Task"
        Resource = aws_lambda_function.get_standings_data_lambda_function.arn
        Next = "StoreStandingsData"
      }
      StoreStandingsData = {
        Type = "Task"
        Resource = aws_lambda_function.store_standings_data_lambda_function.arn
        Next = "GetPersonalizedStandingsData"
      }
      GetPersonalizedStandingsData = {
        Type = "Task"
        Resource = aws_lambda_function.personalized_standings_lambda_function.arn
        End = true
      }
    }
  })
}
