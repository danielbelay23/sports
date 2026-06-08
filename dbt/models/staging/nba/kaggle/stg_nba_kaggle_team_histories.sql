{{ config(materialized='table') }}

with final as (
    select
        safe_cast(`teamId` as int64) as team_id,
        safe_cast(`teamCity` as string) as team_city,
        safe_cast(`teamName` as string) as team_name,
        safe_cast(`teamAbbrev` as string) as team_abbrev,
        safe_cast(`seasonFounded` as int64) as season_founded,
        safe_cast(`seasonActiveTill` as int64) as season_active_till,
        safe_cast(`league` as string) as league

    from {{ source('nba_raw', 'team_histories') }}
    where league = 'NBA'
)

select *
from final
