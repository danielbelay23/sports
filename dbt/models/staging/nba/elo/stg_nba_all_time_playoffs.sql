{{ config(materialized='table') }}

with all_time as (
    select
        cast(game_id as string) as game_id,
        safe.parse_date('%Y-%m-%d', cast(date as string)) as date_game,
        safe_cast(season as int64) as season,
        safe_cast(is_playoff as int64) as is_playoff,
        safe_cast(neutral as int64) as neutral,
        cast(home_franch as string) as team_id,
        cast(away_franch as string) as opp_id,

        safe_cast(home_pts as int64) as home_pts,
        safe_cast(away_pts as int64) as away_pts,
        safe_cast(mov as int64) as mov,
        safe_cast(home_win as int64) as home_win,

        safe_cast(elo_home_reg_pre as float64) as elo_home_reg_pre,
        safe_cast(elo_away_reg_pre as float64) as elo_away_reg_pre,
        safe_cast(elo_home_po_pre as float64) as elo_home_po_pre,
        safe_cast(elo_away_po_pre as float64) as elo_away_po_pre,

        safe_cast(p_home_reg as float64) as p_home_reg,
        safe_cast(p_home_po as float64) as p_home_po,
        safe_cast(p_home_used as float64) as p_home_used,

        safe_cast(delta_reg as float64) as delta_reg,
        safe_cast(delta_po as float64) as delta_po,

        safe_cast(elo_home_reg_post as float64) as elo_home_reg_post,
        safe_cast(elo_away_reg_post as float64) as elo_away_reg_post,
        safe_cast(elo_home_po_post as float64) as elo_home_po_post,
        safe_cast(elo_away_po_post as float64) as elo_away_po_post

    from {{ source('nba_elo', 'nba_elo_all_time') }}
)

select
    *
from all_time
where is_playoff = 1