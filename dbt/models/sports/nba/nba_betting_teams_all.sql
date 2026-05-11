{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `league_id`,
    `team_id`,
    `min_year`,
    `max_year`,
    `abbreviation`
from {{ ref('stg_nba_teams_all') }}
