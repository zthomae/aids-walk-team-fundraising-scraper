import pytest
import os

import boto3
from moto import mock_dynamodb2
from moto import mock_ses


@pytest.fixture()
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ["AWS_DEFAULT_REGION"] = "us-east-2"
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"


@pytest.fixture()
def dynamodb(aws_credentials):
    with mock_dynamodb2():
        yield boto3.client("dynamodb")


@pytest.fixture()
def ses(aws_credentials):
    with mock_ses():
        yield boto3.client("ses")
