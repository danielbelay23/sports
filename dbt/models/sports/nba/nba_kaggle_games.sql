{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `gameId` as game_id,
    `gameDateTimeEst` as game_datetime_est,
    `hometeamCity` as home_team_city,
    `hometeamName` as home_team_name,
    `hometeamId` as home_team_id,
    `awayteamCity` as away_team_city,
    `awayteamName` as away_team_name,
    `awayteamId` as away_team_id,
    `homeScore` as home_score,
    `awayScore` as away_score,
    `winner` as winner,
    `gameType` as game_type,
    `gameSubtype` as game_subtype,
    `gameLabel` as game_label,
    `gameSubLabel` as game_sub_label,
    `seriesGameNumber` as series_game_number,
    `attendance` as attendance,
    `arenaId` as arena_id,
    `arenaName` as arena_name,
    `arenaCity` as arena_city,
    `arenaState` as arena_state,
    `officials` as officials,
    `gameDate` as game_date
from {{ source('nba_raw', 'games') }}
