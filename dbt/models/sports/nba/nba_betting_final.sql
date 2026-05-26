{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `game_id`,
    `game_date`,
    `matchup`,
    `team_id`,
    `is_home`,
    `w`,
    `l`,
    `w_pct`,
    `a_team_id`,
    `season_year`,
    `season_type`,
    `season`

from {{ ref('stg_nba_games_all') }} a
left join {{ ref('stg_nba_betting_money_line') }} b
on a.game_id = b.game_id
left join {{ ref('stg_nba_betting_spread') }} c
on a.game_id = c.game_id
left join {{ ref('stg_nba_betting_totals') }} d
on a.game_id = d.game_id
