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
        ) as series_id,
        cast(cast(series_game_number as float64) as int64) as series_game_number
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

sub_final as (
    select
        player_playoff_games.person_id,
        player_playoff_games.first_name,
        player_playoff_games.last_name,
        player_playoff_games.series_id,
        player_playoff_games.series_game_number,
        player_playoff_games.game_id,
        player_playoff_games.game_datetime_est,
        team_statistics.win,
        round(implied_probs.implied_win_prob, 4) as implied_win_prob,
        round(cast(team_statistics.win as float64) - implied_probs.implied_win_prob, 4) as game_residual,
        round(
            sum(cast(team_statistics.win as float64) - implied_probs.implied_win_prob)
                over (
                    partition by player_playoff_games.person_id
                    order by player_playoff_games.game_ts
                ),
            4
        ) as cumulative_career_game_residual,
        round(
            sum(cast(team_statistics.win as float64) - implied_probs.implied_win_prob)
                over (
                    partition by player_playoff_games.person_id, player_playoff_games.series_id
                    order by player_playoff_games.series_start_ts
                ),
            4
        ) as cumulative_series_residual,
        round(
            avg(cast(team_statistics.win as float64) - implied_probs.implied_win_prob)
                over (
                    partition by player_playoff_games.person_id, player_playoff_games.series_id
                    order by player_playoff_games.series_start_ts
                ),
            4
        ) as average_series_residual,
        dense_rank() over (
            partition by player_playoff_games.person_id
            order by player_playoff_games.series_start_ts
        ) as player_series_order
    from player_playoff_games
    inner join eligible_players
        on player_playoff_games.person_id = eligible_players.person_id
    inner join {{ ref('nba_kaggle_team_statistics') }} as team_statistics
        on cast(player_playoff_games.game_id as int64) = team_statistics.game_id
            and player_playoff_games.player_team_id = team_statistics.team_id
    left join implied_probs
        on cast(player_playoff_games.game_id as int64) = implied_probs.game_id
            and player_playoff_games.player_team_id = implied_probs.target_team_id
),

max_career_residual as (
    select
        person_id,
        first_name,
        last_name,
        max(cumulative_career_game_residual) as max_cumulative_career_game_residual
    from sub_final
    group by 1, 2, 3
),

final as (
    select
        sub_final.*,
        max_career_residual.max_cumulative_career_game_residual
    from sub_final
    inner join max_career_residual
        on sub_final.person_id = max_career_residual.person_id
    where implied_win_prob is not null
        and game_residual is not null
        and cumulative_career_game_residual is not null
        and cumulative_series_residual is not null
)

select
    *
from final
