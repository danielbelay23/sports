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
    `arenaCity` as arena_city,
    `arenaState` as arena_state,
    `arenaName` as arena_name,
    `gameLabel` as game_label,
    `gameSubLabel` as game_sub_label,
    `gameSubtype` as game_subtype,
    `gameSequence` as game_sequence,
    `seriesGameNumber` as series_game_number,
    `seriesText` as series_text,
    `weekNumber` as week_number,
    `hometeamId` as home_team_id,
    `awayteamId` as away_team_id

from {{ source('nba_raw', 'league_schedule_2024_25') }}
