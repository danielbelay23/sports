{{
    config(
        materialized='view'
    )
}}

with final as (
    select
        person_id,
        any_value(first_name) as first_name,
        any_value(last_name) as last_name,
        safe_cast(year_id as int64) as year_id,
        series_id,
        player_team_id,
        opponent_team_id,

        min(date_game) as series_start_date,
        max(date_game) as series_end_date,
        count(distinct kaggle_game_id) as player_series_games_played,

        sum(num_minutes) as series_minutes,
        sum(points) as series_points,
        sum(assists) as series_assists,
        sum(rebounds_total) as series_rebounds_total,
        sum(blocks) as series_blocks,
        sum(steals) as series_steals,
        sum(field_goals_attempted) as series_field_goals_attempted,
        sum(field_goals_made) as series_field_goals_made,
        safe_divide(sum(field_goals_made), sum(field_goals_attempted)) as series_field_goals_percentage,
        sum(turnovers) as series_turnovers,

        max(series_win) as actual_win,
        max(series_forecast) as expected_win_prob,
        max(series_money_line) as expected_money_line,
        max(series_residual) as series_residual,

        sum(game_residual) as series_sum_game_residual,
        avg(player_game_forecast) as avg_player_game_forecast

    from {{ ref('elo_games_mapping') }}
    where person_id is not null
        and series_id is not null
        and series_win is not null
        and series_forecast is not null
        and series_forecast > 0
        and series_forecast < 1
    group by
        person_id,
        year_id,
        series_id,
        player_team_id,
        opponent_team_id
)

select *
from final