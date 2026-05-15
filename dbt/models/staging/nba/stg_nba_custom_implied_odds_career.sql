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

player_playoff_games as (
    select
        person_id,
        first_name,
        last_name,
        game_id,
        cast(player_team_id as int64) as player_team_id,
        cast(opponent_team_id as int64) as opponent_team_id,
        game_label,
        game_datetime_est,
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

eligible_players as (
    select
        person_id
    from player_playoff_games
    group by person_id
    having count(distinct series_id) > 10
),

final as (
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
                    partition by player_playoff_games.person_id, player_playoff_games.series_id
                    order by cast(player_playoff_games.game_datetime_est as timestamp)
                ),
            4
        ) as cumulative_series_residual,
        dense_rank() over (
            partition by player_playoff_games.person_id
            order by substr(player_playoff_games.series_id, 1, 4), player_playoff_games.series_id
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
)

select
    *
from final
where implied_win_prob is not null
    and game_residual is not null
    and cumulative_series_residual is not null
