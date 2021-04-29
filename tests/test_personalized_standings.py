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
        json.dumps(get_standings_data(event, None)),
        f"get_standings_data_minimal_team_{team_id}.json",
    )
