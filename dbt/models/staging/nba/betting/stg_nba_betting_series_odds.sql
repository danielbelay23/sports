{{ config(materialized='table') }}

select
    safe_cast(`year` as int64) as year,
    safe_cast(`conference` as string) as conference,
    safe_cast(`round` as string) as round,
    safe_cast(`home_team` as string) as home_team,
    safe_cast(`home_seed` as int64) as home_seed,
    if(`home_odds` = 'N/A', null, safe_cast(`home_odds` as float64)) as home_odds,
    safe_cast(`away_team` as string) as away_team,
    safe_cast(`away_seed` as int64) as away_seed,
    if(`away_odds` = 'N/A', null, safe_cast(`away_odds` as float64)) as away_odds,
    safe_cast(`winner` as string) as winner,
    safe_cast(`series_score` as string) as series_score,
    safe_cast(`games_in_series` as int64) as games_in_series,
    safe_cast(`home_id` as int64) as home_id,
    safe_cast(`away_id` as int64) as away_id,
    safe_cast(`winner_id` as int64) as winner_id

from {{ source('nba_odds_raw', 'nba_betting_series_odds') }}
