{{
    config(
        materialized='view'
    )
}}

select
    person_id,
    first_name,
    last_name,
    birth_date,
    school,
    country,
    height_inches,
    body_weight_lbs,
    jersey,
    guard,
    forward,
    center,
    dleague_flag,
    nba_flag,
    games_played_flag,
    draft_year,
    draft_round,
    draft_number,
    from_year,
    to_year

from {{ ref('stg_nba_kaggle_players') }}
