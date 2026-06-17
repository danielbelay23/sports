{{ config(materialized='table') }}


    select
        team_id,
        team_abbrev,
        full_team_name,
        team_city,
        team_name,
        franch,
        year,
        games,
        wins,
        losses,
        points_for,
        points_against,
        points_per_game_diff,
        offense_rating,
        defense_rating,
        elo_preseason,
        elo_midseason,
        elo_end_of_regular_season,
        playoffs_won,
        playoffs_lost,
        playoff_outcome,
        playoff_elo,
        coaches

    from {{ ref('stg_nba_elo_team_seasons') }}
