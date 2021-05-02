from datetime import datetime
import json
import pathlib

import pytest
from freezegun import freeze_time

from handlers.personalized_standings import *


@pytest.fixture()
def minimal_team_page(event, requests_mock):
    team_id = event["team_id"]
    fixture_path = (
        pathlib.Path(__file__)
        .parent.absolute()
        .joinpath("fixtures/minimal_team_page.html")
    )
    with open(fixture_path) as f:
        data = f.read()
    requests_mock.get(
        f"https://www.aidswalk.net/wisconsin/Team/View/{team_id}", text=data
    )


@freeze_time("2021-03-14 15:30:01")
@pytest.mark.parametrize(
    "event",
    [{"team_id": "123"}, {"team_id": "456", "foo": "bar"}],
)
def test_get_standings_data(event, minimal_team_page, snapshot):
    team_id = event["team_id"]
    snapshot.assert_match(
        json.dumps(get_standings_data(event, None), indent=4),
        f"get_standings_data_minimal_team_{team_id}.json",
    )


@pytest.fixture()
def event_with_scores():
    return {
        "team_id": "1234",
        "timestamp": datetime(2021, 1, 14, 13, 57).isoformat(),
        "scores": [
            {"amount": Decimal("127.50"), "name": "First Person"},
            {"amount": Decimal("56.25"), "name": "Second Person"},
            {"amount": Decimal("5634.05"), "name": "Third Person"},
        ],
        "name": "Third Person",
    }


@pytest.fixture()
def large_sorted_scores():
    return [
        {"amount": Decimal("1500.00"), "name": "First Person"},
        {"amount": Decimal("1400.00"), "name": "Second Person"},
        {"amount": Decimal("1300.00"), "name": "Third Person"},
        {"amount": Decimal("1200.00"), "name": "Fourth Person"},
        {"amount": Decimal("1100.00"), "name": "Fifth Person"},
        {"amount": Decimal("1000.00"), "name": "Sixth Person"},
        {"amount": Decimal("900.00"), "name": "Seventh Person"},
        {"amount": Decimal("800.00"), "name": "Eighth Person"},
        {"amount": Decimal("700.00"), "name": "Ninth Person"},
        {"amount": Decimal("600.00"), "name": "Tenth Person"},
        {"amount": Decimal("500.00"), "name": "Eleventh Person"},
        {"amount": Decimal("400.00"), "name": "Twelfth Person"},
        {"amount": Decimal("300.00"), "name": "Thirteenth Person"},
        {"amount": Decimal("200.00"), "name": "Fourteenth Person"},
        {"amount": Decimal("100.00"), "name": "Fifteenth Person"},
    ]


def test_store_standings_data(mocker, dynamodb, event_with_scores):
    score_table_name = "test_table"
    dynamodb.create_table(
        TableName=score_table_name,
        KeySchema=[
            {"AttributeName": "run_id", "KeyType": "HASH"},
            {"AttributeName": "name", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "run_id", "AttributeType": "S"},
            {"AttributeName": "name", "AttributeType": "S"},
        ],
    )
    mocker.patch.dict(
        "os.environ",
        {"SCORE_TABLE_NAME": score_table_name},
    )
    expected_entries = [
        {
            "amount": {"N": score["amount"]},
            "name": {"S": score["name"]},
            "timestamp": {"S": event_with_scores["timestamp"]},
            "team_id": {"S": event_with_scores["team_id"]},
            "run_id": {
                "S": f"{event_with_scores['team_id']}_{event_with_scores['timestamp']}"
            },
        }
        for score in event_with_scores["scores"]
    ]
    assert store_standings_data(event_with_scores, None) == event_with_scores

    item_response = dynamodb.scan(TableName=score_table_name)

    def order_entries(entries):
        sorted(entries, key=lambda entry: entry["run_id"]["S"])

    assert order_entries(expected_entries) == order_entries(item_response["Items"])


def test_personalized_standings(mocker, ses, event_with_scores):
    email_sender = "hi@example.com"
    email_recipient = "bob@example.com"
    ses.verify_email_address(EmailAddress=email_sender)
    ses.verify_email_address(EmailAddress=email_recipient)
    mocker.patch.dict(
        "os.environ",
        {
            "EMAIL_SENDER": email_sender,
            "EMAIL_RECIPIENT": email_recipient,
            "TEMPLATE_PATH": "src/handlers/templates",
            "TIMEZONE": "America/Chicago",
        },
    )
    ses_response = personalized_standings(event_with_scores, None)
    assert ses_response == event_with_scores


@pytest.mark.parametrize(
    "person",
    [
        "First Person",
        "Third Person",
        "Tenth Person",
        "Eleventh Person",
        "Thirteenth Person",
    ],
)
def test_rendering_event_data(large_sorted_scores, person, snapshot):
    standings_data = personalized_standings_template_data(large_sorted_scores, person)
    snapshot.assert_match(
        json.dumps(standings_data, indent=4),
        f"rendering_test_standings_data.json",
    )
    snapshot.assert_match(
        render_personalized_standings(standings_data, "src/handlers/templates"),
        f"rendering_test_email_body.html",
    )
