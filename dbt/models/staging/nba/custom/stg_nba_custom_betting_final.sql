{{
    config(
        materialized='table'
    )
}}

with money_line as (
    select
        game_id,
        team_id,
        a_team_id,
        round(avg(price1), 2) as avg_money_line_price_home,
        round(avg(price2), 2) as avg_money_line_price_away,
        round(
            avg(
                case
                    when price1 > 0 then safe_divide(100.0, (price1 + 100.0))
                    else safe_divide(ABS(price1), (ABS(price1) + 100.0))
                end
            ), 2
        ) as implied_win_prob_home,
        round(
            avg(
                case
                    when price2 > 0 then safe_divide(100.0, (price2 + 100.0))
                    else safe_divide(ABS(price2), (ABS(price2) + 100.0))
                end
            ), 2
        ) as implied_win_prob_away

    from {{ ref('stg_nba_betting_money_line') }}
    group by 1, 2, 3
)

select
    safe_cast(a.game_id as int64) as game_id,
    safe_cast(a.home_team_id as int64) as home_team_id,
    safe_cast(a.away_team_id as int64) as away_team_id,
    safe_cast(a.game_date as date) as game_date,
    safe_cast(a.matchup as string) as matchup,
    safe_cast(a.season_year as int64) as season_year,
    safe_cast(a.season_type as string) as season_type,
    safe_cast(a.season as string) as season,
    safe_cast(a.home_wl as string) as home_wl,
    safe_cast(a.away_wl as string) as away_wl,
    safe_cast(b.implied_win_prob_home as float64) as implied_win_prob_home,
    safe_cast(b.implied_win_prob_away as float64) as implied_win_prob_away,
    safe_cast(b.avg_money_line_price_home as float64) as avg_money_line_price_home,
    safe_cast(b.avg_money_line_price_away as float64) as avg_money_line_price_away

from {{ ref('stg_nba_betting_games_all') }} a
join money_line b
    on a.game_id = b.game_id
where a.season_type = 'Playoffs'
order by a.game_date asc
