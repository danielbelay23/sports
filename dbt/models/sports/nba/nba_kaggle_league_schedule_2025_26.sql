{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `gameId` as game_id,
    `gameDateTimeEst` as game_datetime_est,
    `gameDay` as game_day,
    `homeTeamId` as home_team_id,
    `awayTeamId` as away_team_id,
    `homeTeamName` as home_team_name,
    `homeTeamCity` as home_team_city,
    `awayTeamName` as away_team_name,
    `awayTeamCity` as away_team_city,
    `arenaName` as arena_name,
    `arenaCity` as arena_city,
    `arenaState` as arena_state,
    `gameLabel` as game_label,
    `gameSubLabel` as game_sub_label,
    `gameSubtype` as game_subtype,
    `seriesGameNumber` as series_game_number,
    `weekNumber` as week_number
from {{ source('nba_raw', 'league_schedule_2025_26') }}
