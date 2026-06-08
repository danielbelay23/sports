{{
    config(
        materialized='view'
    )
}}

select
    `game_id`,
    `book_name`,
    `book_id`,
    `team_id`,
    `a_team_id`,
    `total1`,
    `total2`,
    `price1`,
    `price2`

from {{ ref('stg_nba_betting_totals') }}
