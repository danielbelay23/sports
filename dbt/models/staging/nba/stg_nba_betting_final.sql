{{
    config(
        materialized='view'
    )
}}

with money_line as (
  select
    game_id,
    team_id,
    a_team_id,
    round(avg(price1), 2) as avg_money_line_price_home,
    round(avg(price2), 2) as avg_money_line_price_away,
    -- round(safe_divide(avg(price1), (avg(price1) + 100.0)),2) as implied_win_prob_home,
    -- round(safe_divide(avg(price2), (avg(price2) + 100.0)),2) as implied_win_prob_away,
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
  a.game_id,
  a.home_team_id,
  a.away_team_id,
  cast(a.game_date as date) as game_date,
  a.matchup,
  a.season_year,
  a.season_type,
  a.season,
  a.home_wl,
  a.away_wl,
  b.implied_win_prob_home,
  b.implied_win_prob_away,
  b.avg_money_line_price_home,
  b.avg_money_line_price_away
from {{ ref('stg_nba_games_all') }} a
join money_line b
    on a.game_id = b.game_id
    --and a.home_team_id = b.team_id
where a.season_type = "Playoffs"
order by a.game_date asc