{{
    config(
        materialized='view'
    )
}}

select
    `league_id`,
    `team_id`,
    `min_year`,
    `max_year`,
    `abbreviation`

from {{ ref('stg_nba_betting_teams_all') }}
