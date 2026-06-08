{{ config(materialized='table') }}

select
    safe_cast(`gameId` as int64) as game_id,
    safe_cast(`gameDateTimeEst` as timestamp) as game_date_time_est,
    safe_cast(`hometeamCity` as string) as home_team_city,
    safe_cast(`hometeamName` as string) as home_team_name,
    safe_cast(`hometeamId` as int64) as home_team_id,
    safe_cast(`awayteamCity` as string) as away_team_city,
    safe_cast(`awayteamName` as string) as away_team_name,
    safe_cast(`awayteamId` as int64) as away_team_id,
    safe_cast(`homeScore` as int64) as home_score,
    safe_cast(`awayScore` as int64) as away_score,
    safe_cast(`winner` as int64) as winner,
    safe_cast(`gameType` as string) as game_type,
    safe_cast(`gameSubtype` as string) as game_subtype,
    safe_cast(`gameLabel` as string) as game_label,
    safe_cast(`gameSubLabel` as string) as game_sublabel,
    safe_cast(`seriesGameNumber` as string) as series_game_number,
    safe_cast(`attendance` as int64) as attendance,
    safe_cast(`arenaId` as int64) as arena_id,
    safe_cast(`arenaName` as string) as arena_name,
    safe_cast(`arenaCity` as string) as arena_city,
    safe_cast(`arenaState` as string) as arena_state,
    safe_cast(`officials` as string) as officials,
    safe_cast(`gameDate` as timestamp) as game_date

from {{ source('nba_raw', 'games') }}
