# Sports – ETL and DS analyses for NBA and NFL

- ****NFL data is TBD and not merged yet****

NBA and NFL data modeling project for a broader Streamlit analytics effort. This repo owns the ingestion-adjacent dbt work that turns raw NBA and NFL and betting data landed in Google Cloud into curated BigQuery views for the app layer.

The current focus is the BigQuery + dbt path that supports a Streamlit dashboard for NBA player and betting-market analysis, including future models for implied probability, residuals, and cumulative playoff performance against market expectations.

## Architecture

```text
Raw files in GCS
  -> BigQuery raw datasets
  -> dbt source declarations
  -> dbt staging views
  -> dbt NBA models (plan to do the same w NFL)
  -> Streamlit / analytics app queries
```

### 1. GCS raw landing

Raw source files should land in Google Cloud Storage before they are loaded into the warehouse. GCS is the file lake and lineage boundary: keep original Kaggle/NBA exports, odds CSVs, scraper outputs, and future archive pulls there rather than treating dbt as an ingestion tool.

Expected source families:

- `kaggle data/`: NBA games, schedules, players, teams, play-by-play, and box-score style statistics.
- `odds_data/`: betting market files such as moneyline, spread, totals, teams, players, and game stats.

The important rule is that raw files stay raw. Cleanups, renames, joins, and probability math belong downstream in BigQuery/dbt models.

### 2. BigQuery raw datasets

GCS files are loaded into BigQuery raw datasets in project `belayground-467323`:

- `nba_raw`: NBA historical and Kaggle-style basketball tables.
- `nba_odds_raw`: betting market and odds tables.

These datasets should preserve the source shape as closely as possible. When files have messy or inconsistent types, load conservatively, including string-first columns where BigQuery autodetection would make brittle choices. The raw layer should answer: "What did the source give us?"

### 3. dbt sources

dbt declares the BigQuery raw tables in:

- `dbt/models/sources/nba_raw.yml`
- `dbt/models/sources/nba_odds_raw.yml`

Sources are dbt's contract with the warehouse raw layer. They do not transform data by themselves; they let models reference raw BigQuery tables with `source()` instead of hard-coding database and schema names.

Example:

```sql
from {{ source('nba_raw', 'games') }}
```

Current declared source tables include:

- `nba_raw`: `games`, `players`, `player_statistics`, `player_statistics_extended`, `team_statistics`, `team_statistics_extended`, `team_histories`, `play_by_play`, and league schedules.
- `nba_odds_raw`: `nba_betting_money_line`, `nba_betting_spread`, `nba_betting_totals`, `nba_games_all`, `nba_players_all`, `nba_players_game_stats`, and `nba_teams_all`.

### 4. dbt staging

Staging models live in `dbt/models/staging/nba/` and are materialized as views. They are the first dbt layer above raw sources.

Purpose of staging:

- Isolate direct access to raw source tables.
- Provide stable model names like `stg_nba_games` and `stg_nba_betting_money_line`.
- Create a safe place for light cleanup, type casting, column naming, and source-specific normalization.
- Give downstream models a consistent interface even if raw file loading changes later.

At the moment, several staging models are thin pass-through views over `source()` tables. That is acceptable early in the project because it establishes lineage. As the modeling work matures, staging should become the place where raw column names and raw type issues are normalized.

### 5. dbt curated models

Curated NBA models live in `dbt/models/sports/nba/`. These are the views the analytics and Streamlit layer should prefer.

Naming keeps source lineage visible:

- `nba_kaggle_*`: modeled tables derived from the NBA/Kaggle-style raw data in `nba_raw`.
- `nba_betting_*`: modeled tables derived from betting-market raw data in `nba_odds_raw`.

The final models should use explicit column lists, readable aliases, and `ref()` references to staging models when a staging model exists. These models are where the project should evolve from raw table cleanup into analytical entities such as:

- canonical games and series
- normalized teams and players
- game-level betting lines
- devigged implied probabilities
- series-level expected win probabilities
- player series outcomes
- residual and cumulative residual metrics

With the current `dbt_project.yml`, models default to views. Staging uses the custom schema `nba_staging`, and curated NBA models use the custom schema `nba`. If the active dbt profile target schema is `dbt`, dbt's default BigQuery schema naming will materialize these as datasets such as `dbt_nba_staging` and `dbt_nba`.

## Project Layout

```text
.
|-- dbt/
|   |-- dbt_project.yml
|   |-- packages.yml
|   `-- models/
|       |-- sources/
|       |   |-- nba_raw.yml
|       |   `-- nba_odds_raw.yml
|       |-- staging/nba/
|       `-- sports/nba/
|-- scrapers/
|   `-- odds_scraper.py
`-- README.md
```

## Running dbt

From the dbt project directory:

```bash
cd dbt
dbt deps
dbt debug
dbt build
```

Useful focused builds:

```bash
dbt build --select path:models/staging/nba
dbt build --select path:models/sports/nba
```

## Streamlit Integration

The Streamlit app should query curated dbt models, not raw BigQuery datasets. In practice, the app layer should treat the dbt output dataset as its semantic data contract:

```text
Streamlit page
  -> BigQuery client/query
  -> curated dbt views in the NBA model dataset
  -> cached app DataFrames and visualizations
```

For performance, the app should cache BigQuery query results with `st.cache_data` and cache reusable clients/connections with `st.cache_resource`. Any downstream in-memory shaping for charts can happen in the app, but durable business logic belongs in dbt so the models remain testable, versioned, and reusable.

## Development Notes

- Keep raw ingestion and warehouse loading separate from dbt transformations.
- Add new raw tables first to `models/sources/*.yml`.
- Add or update staging models before building downstream marts.
- Prefer explicit columns over `select *` in curated models.
- Use `ref()` between dbt models and `source()` only at the raw boundary.
- Add dbt tests as model contracts stabilize, especially for IDs, dates, joins, and probability fields.

