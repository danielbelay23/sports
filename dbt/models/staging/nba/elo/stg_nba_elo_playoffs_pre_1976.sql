{{ config(materialized='table') }}

with final as (
    select
        safe_cast(gameorder as int64) as game_order,
        safe_cast(game_id as string) as game_id,
        safe_cast(lg_id as string) as lg_id,
        safe_cast(_iscopy as int64) as is_copy,
        safe_cast(year_id as int64) as year_id,
        safe_cast(date_game as date) as date_game,
        safe_cast(seasongame as int64) as season_game,
        safe_cast(is_playoffs as int64) as is_playoffs,
        safe_cast(team_id as string) as team_id,
        safe_cast(fran_id as string) as fran_id,
        safe_cast(pts as int64) as pts,
        safe_cast(elo_i as float64) as elo_i,
        safe_cast(elo_n as float64) as elo_n,
        safe_cast(win_equiv as float64) as win_equiv,
        safe_cast(opp_id as string) as opp_id,
        safe_cast(opp_fran as string) as opp_fran,
        safe_cast(opp_pts as int64) as opp_pts,
        safe_cast(opp_elo_i as float64) as opp_elo_i,
        safe_cast(opp_elo_n as float64) as opp_elo_n,
        safe_cast(game_location as string) as game_location,
        safe_cast(game_result as string) as game_result

    from {{ source('nba_elo', 'nba_elo_playoffs_pre1976') }}
)

select *
from final
