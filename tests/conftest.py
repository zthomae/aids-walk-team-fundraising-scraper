import pytest
import os

import boto3
from moto import mock_dynamodb2
from moto import mock_ses


@pytest.fixture()
def aws_credentials(monkeypatch):
    """Mocked AWS Credentials for moto."""
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-2")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")


@pytest.fixture()
def dynamodb(aws_credentials):
    with mock_dynamodb2():
        yield boto3.client("dynamodb")


@pytest.fixture()
def ses(aws_credentials):
    with mock_ses():
        yield boto3.client("ses")
