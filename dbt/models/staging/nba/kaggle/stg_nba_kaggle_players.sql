{{ config(materialized='table') }}

select
    safe_cast(`personId` as int64) as person_id,
    safe_cast(`firstName` as string) as first_name,
    safe_cast(`lastName` as string) as last_name,
    safe_cast(`birthDate` as date) as birth_date,
    safe_cast(`school` as string) as school,
    safe_cast(`country` as string) as country,
    safe_cast(`heightInches` as int64) as height_inches,
    safe_cast(`bodyWeightLbs` as int64) as body_weight_lbs,
    safe_cast(`jersey` as string) as jersey,
    safe_cast(`guard` as int64) as guard,
    safe_cast(`forward` as int64) as forward,
    safe_cast(`center` as int64) as center,
    safe_cast(`dleagueFlag` as int64) as dleague_flag,
    safe_cast(`nbaFlag` as int64) as nba_flag,
    safe_cast(`gamesPlayedFlag` as int64) as games_played_flag,
    safe_cast(`draftYear` as int64) as draft_year,
    safe_cast(`draftRound` as int64) as draft_round,
    safe_cast(`draftNumber` as int64) as draft_number,
    safe_cast(`fromYear` as int64) as from_year,
    safe_cast(`toYear` as int64) as to_year

from {{ source('nba_raw', 'players') }}
