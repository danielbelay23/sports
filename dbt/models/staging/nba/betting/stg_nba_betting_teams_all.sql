{{ config(materialized='table') }}

select
    safe_cast(league_id as int64) as league_id,
    safe_cast(team_id as int64) as team_id,
    safe_cast(min_year as int64) as min_year,
    safe_cast(max_year as int64) as max_year,
    safe_cast(abbreviation as string) as abbreviation

from {{ source('nba_odds_raw', 'nba_teams_all') }}
