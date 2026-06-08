{{
    config(
        materialized='view'
    )
}}

select
    `game_id`,
    `game_date`,
    `matchup`,
    `home_team_id`,
    `away_team_id`,
    `season_year`,
    `season_type`,
    `season`,
    `home_pts`,
    `away_pts`,
    `home_wl`,
    `away_wl`

from {{ ref('stg_nba_betting_games_all') }}
