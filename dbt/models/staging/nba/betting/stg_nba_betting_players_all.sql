{{ config(materialized='table') }}

select
    safe_cast(person_id as int64) as person_id,
    safe_cast(display_last_comma_first as string) as display_last_comma_first,
    safe_cast(display_first_last as string) as display_first_last,
    safe_cast(rosterstatus as bool) as rosterstatus,
    safe_cast(from_year as int64) as from_year,
    safe_cast(to_year as int64) as to_year,
    safe_cast(playercode as string) as playercode,
    safe_cast(games_played_flag as bool) as games_played_flag,
    safe_cast(position as string) as position,
    safe_cast(draft_year as int64) as draft_year,
    safe_cast(draft_round as int64) as draft_round,
    safe_cast(draft_num as string) as draft_num,
    safe_cast(birth_date as string) as birth_date,
    safe_cast(height_feet as int64) as height_feet,
    safe_cast(height_inches as int64) as height_inches,
    safe_cast(height as float64) as height,
    safe_cast(weight as int64) as weight,
    safe_cast(season_exp as int64) as season_exp,
    safe_cast(jersey as string) as jersey,
    safe_cast(school as string) as school,
    safe_cast(country as string) as country,
    safe_cast(last_affiliation as string) as last_affiliation

from {{ source('nba_odds_raw', 'nba_players_all') }}
