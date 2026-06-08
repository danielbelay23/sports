{{
    config(
        materialized='view'
    )
}}

select
    game_id,
    game_date_time_est,
    home_team_city,
    home_team_name,
    home_team_id,
    away_team_city,
    away_team_name,
    away_team_id,
    home_score,
    away_score,
    winner,
    game_type,
    game_subtype,
    regexp_replace(
        lower(concat(extract(year from date(game_date_time_est)), game_label)), r'[^a-z0-9]', ''
    ) as series_id,
    case
        when game_label is null then null
        else replace(game_label, '- ', '')
    end as game_label,
    cast(case
        when series_game_number like "%1%" then "1"
        else series_game_number end as float64
    ) as series_game_number,
    game_sublabel,
    attendance,
    arena_id,
    arena_name,
    arena_city,
    arena_state,
    officials,
    game_date

from {{ ref('stg_nba_kaggle_games') }}
