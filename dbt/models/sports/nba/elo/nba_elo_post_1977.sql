{{ config(materialized='table') }}

with final as (
    select
        game_order,
        game_id,
        lg_id,
        is_copy,
        year_id,
        date_game,
        season_game,
        is_playoffs,
        team_id,
        fran_id,
        pts,
        elo_i,
        elo_n,
        win_equiv,
        opp_id,
        opp_fran,
        opp_pts,
        opp_elo_i,
        opp_elo_n,
        game_location,
        game_result,
        forecast,
        notes

    from {{ ref('stg_nba_elo_post_1977') }}
)

select *
from final
