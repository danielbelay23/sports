{{ config(materialized='table') }}


    select
        game_id,
        date_game,
        season,
        is_playoff,
        neutral,
        team_id,
        opp_id,
        home_pts,
        away_pts,
        mov,
        home_win,
        elo_home_reg_pre,
        elo_away_reg_pre,
        elo_home_po_pre,
        elo_away_po_pre,
        p_home_reg,
        p_home_po,
        p_home_used,
        delta_reg,
        delta_po,
        elo_home_reg_post,
        elo_away_reg_post,
        elo_home_po_post,
        elo_away_po_post

    from {{ ref('stg_nba_elo_playoff_games') }}
