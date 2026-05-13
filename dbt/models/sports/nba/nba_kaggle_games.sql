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
    case
        when `gameLabel` is null then null
        else replace(`gameLabel`, '- ', '')
    end as game_label,
    cast(case
        when `seriesGameNumber` like "%1%" then "1"
        else `seriesGameNumber` end as float64
    ) as series_game_number,
    `gameSubLabel` as game_sub_label,
    `attendance` as attendance,
    `arenaId` as arena_id,
    `arenaName` as arena_name,
    `arenaCity` as arena_city,
    `arenaState` as arena_state,
    `officials` as officials,
    `gameDate` as game_date
from {{ source('nba_raw', 'games') }}
