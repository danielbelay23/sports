{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `game_id`,
    `book_name`,
    `book_id`,
    `team_id`,
    `a_team_id`,
    `price1`,
    `price2`
from {{ ref('stg_nba_betting_money_line') }}
