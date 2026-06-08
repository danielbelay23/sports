{{ config(materialized='table') }}

select
    safe_cast(game_id as int64)     as game_id,
    safe_cast(book_name as string)  as book_name,
    safe_cast(book_id as int64)     as book_id,
    safe_cast(team_id as int64)     as team_id,
    safe_cast(a_team_id as int64)   as a_team_id,
    safe_cast(price1 as float64)    as price1,
    safe_cast(price2 as float64)    as price2

from {{ source('nba_odds_raw', 'nba_betting_money_line') }}
