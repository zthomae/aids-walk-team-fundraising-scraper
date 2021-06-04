import boto3
from bs4 import BeautifulSoup
from datetime import datetime
from decimal import Decimal
from jinja2 import Environment, FileSystemLoader
import os
import pytz
import requests


def get_standings_data(event, context):
    team_id = event["team_id"]
    team_score_data = team_scores(team_id)
    scores_dict = {
        "scores": team_score_data["scores"],
        "total": team_score_data["total"],
        "timestamp": datetime.utcnow().isoformat(),
    }
    scores_dict.update(event)
    return scores_dict


def store_standings_data(event, context):
    dynamodb = boto3.resource("dynamodb")
    scores_table = dynamodb.Table(os.environ.get("SCORE_TABLE_NAME"))
    scores = event["scores"]
    timestamp = event["timestamp"]
    team_id = event["team_id"]
    with scores_table.batch_writer() as batch:
        for entry in scores:
            entry_to_save = entry.copy()
            entry_to_save["amount"] = Decimal(str(entry_to_save["amount"]))
            entry_to_save["timestamp"] = timestamp
            entry_to_save["team_id"] = team_id
            entry_to_save["run_id"] = f"{team_id}_{timestamp}"
            batch.put_item(Item=entry_to_save)
    return event


def personalized_standings(event, context):
    standings_data = personalized_standings_template_data(
        event["scores"], event["name"], event["total"]
    )
    rendered_standings = render_personalized_standings(
        standings_data, os.environ.get("TEMPLATE_PATH")
    )
    utc_datetime = pytz.utc.localize(datetime.fromisoformat(event["timestamp"]))
    local_datetime = utc_datetime.astimezone(pytz.timezone(os.environ.get("TIMEZONE")))
    friendly_timestamp = local_datetime.strftime("%Y-%m-%d %I:%M %p")
    name = event["name"]
    ses_client = boto3.client("ses")
    ses_client.send_email(
        Source=os.environ.get("EMAIL_SENDER"),
        Destination={"ToAddresses": [os.environ.get("EMAIL_RECIPIENT")]},
        Message={
            "Subject": {
                "Data": f"AIDS Walk Fundraising Update For {name} - {friendly_timestamp}"
            },
            "Body": {"Html": {"Data": rendered_standings}},
        },
    )
    return event


def team_url(team_id):
    return f"https://www.aidswalk.net/wisconsin/Team/View/{team_id}"


def parse_amount(amount_text):
    return float(amount_text[1:].replace(",", ""))


def team_scores(team_id):
    url = team_url(team_id)
    page_resp = requests.get(url)
    if page_resp.status_code != 200:
        raise Exception(f"Received unsuccessful response code {page_resp.status_code}")
    soup = BeautifulSoup(page_resp.text, "html.parser")
    team_member_table = soup.find(id="tblTeamList")
    team_member_rows = team_member_table.find_all(class_="tableRow")
    scores = [
        {
            "name": row.find(class_="tableColName").text,
            "amount": parse_amount(row.find(class_="tableColRaised").text),
        }
        for row in team_member_rows
    ]
    sorted_scores = sorted(scores, key=lambda pair: Decimal(pair["amount"]), reverse=True)
    total = parse_amount(soup.find(id="NewProgressAmtRaised").find(class_="was-raised").text)
    return {
        "scores": sorted_scores,
        "total": total,
    }


def standing_for_name(scores, name):
    for i, entry in enumerate(scores):
        if entry["name"] == name:
            return {"place": i + 1, "amount": entry["amount"]}
    raise Exception(f"Could not find an entry for {name}")


# Credit: https://stackoverflow.com/a/20007730
def ordinal(n):
    return "%d%s" % (n, "tsnrhtdd"[(n // 10 % 10 != 1) * (n % 10 < 4) * n % 10 :: 4])


def format_as_currency(amount):
    return "${:,.2f}".format(Decimal(amount))


def personalized_standings_template_data(scores, name, total_amount):
    placement = standing_for_name(scores, name)
    top_standings = [
        {"name": score["name"], "amount": format_as_currency(score["amount"])}
        for score in scores[:10]
    ]
    return {
        "place": ordinal(placement["place"]),
        "amount": format_as_currency(placement["amount"]),
        "top_standings": top_standings,
        "total_amount": format_as_currency(total_amount),
    }


def render_personalized_standings(standings_data, template_path):
    file_loader = FileSystemLoader(template_path)
    env = Environment(loader=file_loader)
    template = env.get_template("personalized_standings.html.jinja2")
    return template.render(**standings_data)
