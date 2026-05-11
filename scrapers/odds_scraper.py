### STILL NEED TO SAVE RESULTS AS A CSV

from bs4 import BeautifulSoup
from io import StringIO
import requests
import pandas as pd
import csv

url="https://www.covers.com/sportsoddshistory/nba-playoffs-series/?y=0000"

def get_odds_data(url):
    response = requests.get(url)
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
    else:
        print("request to series odds failed")
    table = soup.find("div", class_="responsive-table-wrapper")
    return table

table = get_odds_data(url)

def table_div_to_df(table_div):
    html = StringIO(str(table))
    df = pd.read_html(html, flavor="lxml")[0]
    df.columns = (
        df.columns
        .str.lower()
        .str.replace("/", "_", regex=False)
        .str.replace("-", "_", regex=False)
        .str.replace(r"[^a-z0-9]+", "_", regex=True)
        .str.strip("_")
    )
    df = df.map(lambda x: x.strip() if isinstance(x, str) else x)
    return df

table_div_to_df(table)
