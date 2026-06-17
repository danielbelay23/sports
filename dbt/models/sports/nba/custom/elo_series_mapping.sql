{{
    config(
        materialized='view'
    )
}}

with elo_games as (
    select
        safe_cast(game_id as string) as elo_game_id,
        safe_cast(year_id as int64) as year_id,
        safe_cast(date_game as date) as date_game,
        safe_cast(kaggle_team_id as int64) as kaggle_team_id,
        safe_cast(kaggle_opp_team_id as int64) as kaggle_opp_team_id,
        safe_cast(forecast as float64) as forecast,
        game_result
    from {{ ref('elo_games_all_time') }}
    where kaggle_team_id is not null
        and kaggle_opp_team_id is not null
        and forecast > 0
        and forecast < 1
),

raw_player_games as (
    select
        person_id,
        first_name,
        last_name,
        safe_cast(game_id as string) as kaggle_game_id,
        num_minutes,
        points,
        assists,
        rebounds_total,
        blocks,
        steals,
        field_goals_attempted,
        field_goals_made,
        turnovers,
        safe_cast(player_team_id as int64) as player_team_id,
        safe_cast(opponent_team_id as int64) as opponent_team_id,
        safe_cast(home as int64) as player_home,
        game_label,
        safe_cast(game_date_time_est as timestamp) as game_ts,
        date(safe_cast(game_date_time_est as timestamp)) as game_date,
        regexp_replace(
            lower(concat(
                cast(extract(year from safe_cast(game_date_time_est as timestamp)) as string),
                game_label,
                cast(least(player_team_id, opponent_team_id) as string),
                cast(greatest(player_team_id, opponent_team_id) as string)
            )),
            r'[^a-z0-9]',
            ''
        ) as series_id,
        safe_cast(regexp_extract(series_game_number, r'\d+') as int64) as series_game_number
    from {{ ref('stg_nba_kaggle_player_statistics') }}
    where game_type = 'Playoffs'
),

player_games as (
    select
        person_id,
        kaggle_game_id,
        any_value(first_name) as first_name,
        any_value(last_name) as last_name,
        sum(num_minutes) as num_minutes,
        sum(points) as points,
        sum(assists) as assists,
        sum(rebounds_total) as rebounds_total,
        sum(blocks) as blocks,
        sum(steals) as steals,
        sum(field_goals_attempted) as field_goals_attempted,
        sum(field_goals_made) as field_goals_made,
        sum(turnovers) as turnovers,
        any_value(player_team_id) as player_team_id,
        any_value(opponent_team_id) as opponent_team_id,
        any_value(player_home) as player_home,
        any_value(game_label) as game_label,
        any_value(game_ts) as game_ts,
        any_value(game_date) as game_date,
        any_value(series_id) as series_id,
        any_value(series_game_number) as series_game_number
    from raw_player_games
    group by
        person_id,
        kaggle_game_id
),

eligible_players as (
    select person_id
    from player_games
    group by person_id
    having count(distinct series_id) > 10
),

joined_games as (
    select
        player_games.*,
        elo_games.year_id,
        elo_games.date_game,
        elo_games.forecast,
        elo_games.game_result,
        min(player_games.game_ts) over (
            partition by player_games.person_id, player_games.series_id
        ) as series_start_ts,
        case
            when elo_games.kaggle_team_id = player_games.player_team_id
                then elo_games.forecast
            when elo_games.kaggle_opp_team_id = player_games.player_team_id
                then 1 - elo_games.forecast
        end as player_game_forecast,
        case
            when elo_games.kaggle_team_id = player_games.player_team_id
                and elo_games.game_result = 'W' then 1
            when elo_games.kaggle_team_id = player_games.player_team_id
                and elo_games.game_result = 'L' then 0
            when elo_games.kaggle_opp_team_id = player_games.player_team_id
                and elo_games.game_result = 'W' then 0
            when elo_games.kaggle_opp_team_id = player_games.player_team_id
                and elo_games.game_result = 'L' then 1
        end as player_win
    from player_games
    inner join eligible_players
        on player_games.person_id = eligible_players.person_id
    inner join elo_games
        on player_games.game_date = elo_games.date_game
        and (
            (
                player_games.player_team_id = elo_games.kaggle_team_id
                and player_games.opponent_team_id = elo_games.kaggle_opp_team_id
            )
            or (
                player_games.player_team_id = elo_games.kaggle_opp_team_id
                and player_games.opponent_team_id = elo_games.kaggle_team_id
            )
        )
),

game_residuals as (
    select
        *,
        round(
            safe_cast(player_win as float64) - player_game_forecast,
            4
        ) as game_residual
    from joined_games
),

series_first_games as (
    select *
    from game_residuals
    qualify row_number() over (
        partition by series_id, player_team_id, opponent_team_id
        order by series_game_number, game_ts, kaggle_game_id
    ) = 1
),

series_format as (
    select
        series_first_games.*,
        case
            when year_id between 1977 and 1983
                and lower(game_label) like '%first%' then 2
            when year_id between 1984 and 2002
                and lower(game_label) like '%first%' then 3
            else 4
        end as required_series_wins,
        case
            when year_id between 1977 and 1983
                and lower(game_label) like '%first%' then ['H', 'A', 'H']
            when year_id between 1984 and 2002
                and lower(game_label) like '%first%' then ['H', 'H', 'A', 'A', 'H']
            when year_id between 1985 and 2013
                and lower(game_label) like '%final%' then ['H', 'H', 'A', 'A', 'A', 'H', 'H']
            else ['H', 'H', 'A', 'A', 'H', 'A', 'H']
        end as home_schedule
    from series_first_games
),

series_game_probabilities as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        required_series_wins,
        array_length(home_schedule) as max_series_games,
        game_offset + 1 as game_number,
        case
            when schedule_location = 'H' and player_home = 1 then player_game_forecast
            when schedule_location = 'A' and player_home = 0 then player_game_forecast
            when schedule_location = 'H' and player_home = 0 then 1 - player_game_forecast
            when schedule_location = 'A' and player_home = 1 then 1 - player_game_forecast
        end as scheduled_player_game_forecast
    from series_format,
        unnest(home_schedule) as schedule_location with offset game_offset
),

series_path_steps as (
    select
        series_game_probabilities.*,
        path_number,
        mod(
            div(
                path_number,
                cast(pow(2, max_series_games - game_number) as int64)
            ),
            2
        ) as player_win_bit
    from series_game_probabilities
    cross join unnest(
        generate_array(0, cast(pow(2, max_series_games) as int64) - 1)
    ) as path_number
),

series_path_steps_with_running as (
    select
        *,
        sum(player_win_bit) over (
            partition by series_id, player_team_id, opponent_team_id, path_number
            order by game_number
            rows between unbounded preceding and current row
        ) as running_player_wins,
        sum(1 - player_win_bit) over (
            partition by series_id, player_team_id, opponent_team_id, path_number
            order by game_number
            rows between unbounded preceding and current row
        ) as running_opponent_wins
    from series_path_steps
),

series_paths as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        required_series_wins,
        path_number,
        exp(sum(ln(case
            when player_win_bit = 1 then scheduled_player_game_forecast
            else 1 - scheduled_player_game_forecast
        end))) as path_probability,
        min(case
            when running_player_wins = required_series_wins
                and running_opponent_wins < required_series_wins
                then game_number
        end) as player_clinch_game,
        min(case
            when running_opponent_wins = required_series_wins
                and running_player_wins < required_series_wins
                then game_number
        end) as opponent_clinch_game
    from series_path_steps_with_running
    group by
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        required_series_wins,
        path_number
),

series_odds as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        sum(case
            when player_clinch_game is not null
                and (opponent_clinch_game is null or player_clinch_game < opponent_clinch_game)
                then path_probability
            else 0
        end) as series_forecast
    from series_paths
    where player_clinch_game is not null
        or opponent_clinch_game is not null
    group by
        year_id,
        series_id,
        player_team_id,
        opponent_team_id
),

series_results as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        case
            when sum(player_win) > sum(1 - player_win) then 1
            when sum(player_win) < sum(1 - player_win) then 0
        end as series_win
    from (
        select distinct
            year_id,
            series_id,
            player_team_id,
            opponent_team_id,
            kaggle_game_id,
            player_win
        from game_residuals
    )
    group by
        year_id,
        series_id,
        player_team_id,
        opponent_team_id
),

series_residuals as (
    select
        series_results.*,
        series_odds.series_forecast,
        case
            when series_odds.series_forecast >= 0.5 then round(
                -100 * safe_divide(
                    series_odds.series_forecast,
                    1 - series_odds.series_forecast
                ) / 5,
                0
            ) * 5
            else round(
                100 * safe_divide(
                    1 - series_odds.series_forecast,
                    series_odds.series_forecast
                ) / 5,
                0
            ) * 5
        end as series_money_line,
        round(
            safe_cast(series_results.series_win as float64) - series_odds.series_forecast,
            4
        ) as series_residual
    from series_results
    inner join series_odds
        on series_results.year_id = series_odds.year_id
        and series_results.series_id = series_odds.series_id
        and series_results.player_team_id = series_odds.player_team_id
        and series_results.opponent_team_id = series_odds.opponent_team_id
    where series_odds.series_forecast > 0
        and series_odds.series_forecast < 1
),

final as (
    select
        game_residuals.person_id,
        any_value(game_residuals.first_name) as first_name,
        any_value(game_residuals.last_name) as last_name,
        game_residuals.year_id,
        game_residuals.series_id,
        game_residuals.player_team_id,
        game_residuals.opponent_team_id,
        round(safe_divide(
            sum(game_residuals.num_minutes),
            count(distinct game_residuals.kaggle_game_id)
        ), 1) as series_minutes_per_game,
        min(game_residuals.date_game) as series_start_date,
        max(game_residuals.date_game) as series_end_date,
        count(distinct game_residuals.kaggle_game_id) as player_series_games_played,
        sum(game_residuals.num_minutes) as series_minutes,
        sum(game_residuals.points) as series_points,
        sum(game_residuals.assists) as series_assists,
        sum(game_residuals.rebounds_total) as series_rebounds_total,
        sum(game_residuals.blocks) as series_blocks,
        sum(game_residuals.steals) as series_steals,
        sum(game_residuals.field_goals_attempted) as series_field_goals_attempted,
        sum(game_residuals.field_goals_made) as series_field_goals_made,
        safe_divide(
            sum(game_residuals.field_goals_made),
            sum(game_residuals.field_goals_attempted)
        ) as series_field_goals_percentage,
        sum(game_residuals.turnovers) as series_turnovers,
        max(series_residuals.series_win) as actual_win,
        max(series_residuals.series_forecast) as expected_win_prob,
        max(series_residuals.series_money_line) as expected_money_line,
        max(series_residuals.series_residual) as series_residual,
        sum(game_residuals.game_residual) as series_sum_game_residual,
        avg(game_residuals.player_game_forecast) as avg_player_game_forecast
    from game_residuals
    inner join series_residuals
        on game_residuals.year_id = series_residuals.year_id
        and game_residuals.series_id = series_residuals.series_id
        and game_residuals.player_team_id = series_residuals.player_team_id
        and game_residuals.opponent_team_id = series_residuals.opponent_team_id
    group by
        game_residuals.person_id,
        game_residuals.year_id,
        game_residuals.series_id,
        game_residuals.player_team_id,
        game_residuals.opponent_team_id
)

select *
from final
