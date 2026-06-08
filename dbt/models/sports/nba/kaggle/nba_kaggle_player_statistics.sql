{{
    config(
        materialized='view'
    )
}}

select
    first_name,
    last_name,
    person_id,
    game_id,
    game_date_time_est,
    player_team_city,
    player_team_name,
    opponent_team_city,
    opponent_team_name,
    game_type,
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
    game_sub_label,
    win,
    home,
    num_minutes,
    points,
    assists,
    blocks,
    steals,
    field_goals_attempted,
    field_goals_made,
    field_goals_percentage,
    three_pointers_attempted,
    three_pointers_made,
    three_pointers_percentage,
    free_throws_attempted,
    free_throws_made,
    free_throws_percentage,
    rebounds_defensive,
    rebounds_offensive,
    rebounds_total,
    fouls_personal,
    turnovers,
    plus_minus_points,
    player_team_id,
    opponent_team_id,
    comment,
    starting_position,
    game_date

from {{ ref('stg_nba_kaggle_player_statistics') }}
