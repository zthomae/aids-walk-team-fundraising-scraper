variable "environment" {
  description = "The name of this deployment instance"
  type = string
}

locals {
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
  inline_policy {
    name = "dynamo-write"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["dynamodb:BatchWriteItem"]
          Effect   = "Allow"
          Resource = aws_dynamodb_table.standings_table.arn
        },
      ]
    })
  }
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
