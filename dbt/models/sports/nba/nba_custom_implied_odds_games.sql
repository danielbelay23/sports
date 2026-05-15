{{
    config(
        materialized='table',
        schema='nba'
    )
}}

select
    *
from {{ ref('stg_nba_custom_implied_odds_games') }}
