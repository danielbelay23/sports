{{
    config(
        materialized='view'
    )
}}

select
    `year`,
    `conference`,
    `round`,
    `home_team`,
    `home_seed`,
    `home_odds`,
    `away_team`,
    `away_seed`,
    `away_odds`,
    `winner`,
    `series_score`,
    `games_in_series`,
    `home_id`,
    `away_id`,
    `winner_id`,
    round(
        case
            when `home_odds` is null then null
            when `home_odds` < 0 then safe_divide(abs(`home_odds`), abs(`home_odds`) + 100)
            when `home_odds` > 0 then safe_divide(100, `home_odds` + 100)
        end,
        4
    ) as `home_implied_probability`,
    round(
        case
            when `away_odds` is null then null
            when `away_odds` < 0 then safe_divide(abs(`away_odds`), abs(`away_odds`) + 100)
            when `away_odds` > 0 then safe_divide(100, `away_odds` + 100)
        end,
        4
    ) as `away_implied_probability`

from {{ ref('stg_nba_betting_series_odds') }}
