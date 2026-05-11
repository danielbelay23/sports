{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `teamId` as team_id,
    `teamCity` as team_city,
    `teamName` as team_name,
    `teamAbbrev` as team_abbrev,
    `seasonFounded` as season_founded,
    `seasonActiveTill` as season_active_till,
    `league` as league

from {{ source('nba_raw', 'team_histories') }}
