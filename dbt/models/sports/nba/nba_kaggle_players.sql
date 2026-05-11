{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `personId` as person_id,
    `firstName` as first_name,
    `lastName` as last_name,
    `birthDate` as birth_date,
    `school` as school,
    `country` as country,
    `heightInches` as height_inches,
    `bodyWeightLbs` as body_weight_lbs,
    `jersey` as jersey,
    `guard` as guard,
    `forward` as forward,
    `center` as center,
    `dleagueFlag` as dleague_flag,
    `nbaFlag` as nba_flag,
    `gamesPlayedFlag` as games_played_flag,
    `draftYear` as draft_year,
    `draftRound` as draft_round,
    `draftNumber` as draft_number,
    `fromYear` as from_year,
    `toYear` as to_year
from {{ source('nba_raw', 'players') }}
