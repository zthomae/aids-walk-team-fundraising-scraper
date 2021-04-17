import boto3
from bs4 import BeautifulSoup
from jinja2 import Environment, FileSystemLoader
import os
import requests


dynamodb = boto3.resource("dynamodb")
scores_table = dynamodb.Table(os.environ.get("SCORE_TABLE_NAME"))


def get_standings_data(event, context):
    team_id = event["team_id"]
    return {"scores": team_scores(team_id)}


def store_standings_data(event, context):
    scores = event["scores"]
    with scores_table.batch_writer() as batch:
        for entry in scores:
            batch.put_item(Item=entry)


def personalized_standings(event, context):
    standings_data = personalized_standings_template_data(event["scores"], event["name"])
    return render_personalized_standings(standings_data, os.environ.get("TEMPLATE_PATH"))


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
    scores = [{"team_id": str(team_id), "name": row.find(class_="tableColName").text, "amount": parse_amount(row.find(class_="tableColRaised").text)}
              for row in team_member_rows]
    return sorted(scores, key=lambda pair: pair["amount"], reverse=True)


def standing_for_name(scores, name):
    for i, entry in enumerate(scores):
        if entry["name"] == name:
            return {"place": i + 1, "amount": entry["amount"]}
    raise Exception(f"Could not find an entry for {name}")


# Credit: https://stackoverflow.com/a/20007730
def ordinal(n):
    return "%d%s" % (n, "tsnrhtdd"[(n // 10 % 10 != 1) * (n % 10 < 4) * n % 10::4])


def format_as_currency(amount):
    return "${:,.2f}".format(amount)


def personalized_standings_template_data(scores, name):
    placement = standing_for_name(scores, name)
    top_standings = [{"name": score["name"], "amount": format_as_currency(score["amount"])}
                     for score in scores[:10]]
    return {
        "place": ordinal(placement["place"]),
        "amount": format_as_currency(placement["amount"]),
        "top_standings": top_standings
    }


def render_personalized_standings(standings_data, template_path):
    file_loader = FileSystemLoader(template_path)
    env = Environment(loader=file_loader)
    template = env.get_template("personalized_standings.html.jinja2")
    return template.render(**standings_data)
