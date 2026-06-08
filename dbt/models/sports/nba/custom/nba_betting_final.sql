{{
    config(
        materialized='view'
    )
}}

select
    `game_id`,
    `home_team_id`,
    `away_team_id`,
    `game_date`,
    `matchup`,
    `season_year`,
    `season_type`,
    `season`,
    `home_wl`,
    `away_wl`,
    `implied_win_prob_home`,
    `implied_win_prob_away`,
    `avg_money_line_price_home`,
    `avg_money_line_price_away`

from {{ ref('stg_nba_custom_betting_final') }}
