{{ config(materialized='table') }}

with home_teams as (
    select
        safe_cast(game_id as int64)          as game_id,
        safe_cast(game_date as date)         as game_date,
        safe_cast(matchup as string)         as matchup,
        safe_cast(team_id as int64)          as home_team_id,
        safe_cast(pts as int64)              as home_pts,
        safe_cast(wl as string)              as home_wl,
        safe_cast(season_year as int64)      as season_year,
        safe_cast(season_type as string)     as season_type,
        safe_cast(season as string)          as season
    from {{ source('nba_odds_raw', 'nba_games_all') }}
    where is_home = true
),

away_teams as (
    select
        safe_cast(game_id as int64)          as game_id,
        safe_cast(team_id as int64)          as away_team_id,
        safe_cast(pts as int64)              as away_pts,
        safe_cast(wl as string)              as away_wl
    from {{ source('nba_odds_raw', 'nba_games_all') }}
    where is_home = false
)

select
    h.game_id,
    h.game_date,
    h.matchup,
    h.home_team_id,
    a.away_team_id,
    h.season_year,
    h.season_type,
    h.season,
    h.home_pts,
    a.away_pts,
    h.home_wl,
    a.away_wl

from home_teams h
join away_teams a
    on h.game_id = a.game_id
