with team_odds as (
    select
        game_id,
        team_id as target_team_id,
        avg(price1) as avg_price
    from {{ ref('nba_betting_spread') }}
    group by 1, 2

    union all

    select
        game_id,
        a_team_id as target_team_id,
        avg(price2) as avg_price
    from {{ ref('nba_betting_spread') }}
    group by 1, 2
),

implied_probs as (
    select
        game_id,
        target_team_id,
        avg_price,
        case
            when avg_price < 0 then abs(avg_price) / (abs(avg_price) + 100.0)
            else 100.0 / (avg_price + 100.0)
        end as implied_win_prob
    from team_odds
),

base_player_games as (
    select
        person_id,
        first_name,
        last_name,
        game_id,
        cast(player_team_id as int64) as player_team_id,
        cast(opponent_team_id as int64) as opponent_team_id,
        game_label,
        game_datetime_est,
        cast(game_datetime_est as timestamp) as game_ts,
        regexp_replace(
            lower(
                concat(
                    cast(extract(year from cast(game_datetime_est as timestamp)) as string),
                    game_label,
                    cast(
                        least(
                            cast(player_team_id as int64),
                            cast(opponent_team_id as int64)
                        ) as string
                    ),
                    cast(
                        greatest(
                            cast(player_team_id as int64),
                            cast(opponent_team_id as int64)
                        ) as string
                    )
                )
            ),
            r'[^a-z0-9]',
            ''
        ) as series_id
    from {{ ref('nba_kaggle_player_statistics') }}
    where game_type = 'Playoffs'
),

player_playoff_games as (
    select
        *,
        min(game_ts) over (partition by person_id, series_id) as series_start_ts
    from base_player_games
),

eligible_players as (
    select
        person_id
    from player_playoff_games
    group by person_id
    having count(distinct series_id) > 10
),

game_residuals as (
    select
        player_playoff_games.person_id,
        player_playoff_games.first_name,
        player_playoff_games.last_name,
        player_playoff_games.series_id,
        player_playoff_games.series_start_ts,
        cast(team_statistics.win as float64) - implied_probs.implied_win_prob as game_residual
    from player_playoff_games
    inner join eligible_players
        on player_playoff_games.person_id = eligible_players.person_id
    inner join {{ ref('nba_kaggle_team_statistics') }} as team_statistics
        on cast(player_playoff_games.game_id as int64) = team_statistics.game_id
            and player_playoff_games.player_team_id = team_statistics.team_id
    left join implied_probs
        on cast(player_playoff_games.game_id as int64) = implied_probs.game_id
            and player_playoff_games.player_team_id = implied_probs.target_team_id
    where implied_probs.implied_win_prob is not null
        and team_statistics.win is not null
),

series_summary as (
    select
        person_id,
        first_name,
        last_name,
        series_id,
        series_start_ts,
        sum(game_residual) as series_sum_residual,
        avg(game_residual) as series_avg_residual
    from game_residuals
    group by 1, 2, 3, 4, 5
),

series_ordered as (
    select
        *,
        dense_rank() over (partition by person_id order by series_start_ts) as player_series_order
    from series_summary
),

cumulative_series as (
    select
        person_id,
        first_name,
        last_name,
        series_id,
        player_series_order,
        series_sum_residual,
        series_avg_residual,
        sum(series_sum_residual) over (
            partition by person_id
            order by player_series_order
        ) as cumulative_sum_series_residual,
        avg(series_avg_residual) over (
            partition by person_id
            order by player_series_order
        ) as cumulative_avg_series_residual
    from series_ordered
),

max_career_residual as (
    select
        person_id,
        max(cumulative_sum_series_residual) as max_cumulative_career_residual
    from cumulative_series
    group by 1
)

select
    cumulative_series.first_name,
    cumulative_series.last_name,
    cumulative_series.series_id,
    cumulative_series.player_series_order,
    round(cumulative_series.series_sum_residual, 4) as series_sum_residual,
    round(cumulative_series.series_avg_residual, 4) as series_avg_residual,
    round(cumulative_series.cumulative_sum_series_residual, 4) as cumulative_sum_series_residual,
    round(cumulative_series.cumulative_avg_series_residual, 4) as cumulative_avg_series_residual
from cumulative_series
inner join max_career_residual
    on cumulative_series.person_id = max_career_residual.person_id
