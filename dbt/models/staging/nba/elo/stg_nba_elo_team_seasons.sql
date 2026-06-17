{{
    config(
        materialized='view'
    )
}}

with team_name_original as (
    select
        team_abbrev,
        full_team_name,
        year,
        split(full_team_name, ' ') as team_name_split
    from {{ source('nba_elo', 'nba_elo_teams_all_time') }}
    where year >= 1977
),

kaggle_team_histories as (
    select
        safe_cast(teamId as int64) as team_id,
        trim(cast(teamCity as string)) as team_city,
        trim(cast(teamName as string)) as team_name,
        trim(cast(teamAbbrev as string)) as team_abbrev,
        safe_cast(seasonFounded as int64) as season_founded,
        safe_cast(seasonActiveTill as int64) as season_active_till,
        cast(League as string) as league
    from {{ source('nba_raw', 'team_histories') }}
    where league in ('NBA', 'ABA')
      and teamName not like '%All-Star%'
      and teamName not like '%Team%'
),

parsed as (
    select
        concat(full_team_name,'_',year,'_',team_abbrev) as id,
        team_abbrev,
        year,
        case
            when full_team_name = 'Spirits of St. Louis' then 'St. Louis'
            when full_team_name like 'Fort Wayne %' then 'Fort Wayne'
            when full_team_name like 'Golden State %' then 'Golden State'
            when full_team_name like 'Kansas City-Omaha %' then 'Kansas City-Omaha'
            when full_team_name like 'Kansas City %' then 'Kansas City'
            when full_team_name like 'Los Angeles %' then 'Los Angeles'
            when full_team_name like 'New Jersey %' then 'New Jersey'
            when full_team_name like 'New Orleans/Oklahoma City %' then 'New Orleans/Oklahoma City'
            when full_team_name like 'New Orleans %' then 'New Orleans'
            when full_team_name like 'New York %' then 'New York'
            when full_team_name like 'Oklahoma City %' then 'Oklahoma City'
            when full_team_name like 'San Antonio %' then 'San Antonio'
            when full_team_name like 'San Diego %' then 'San Diego'
            when full_team_name like 'San Francisco %' then 'San Francisco'
            when full_team_name like 'St. Louis %' then 'St. Louis'
            else team_name_split[safe_offset(0)]
        end as team_city,

        case
            when full_team_name = 'Spirits of St. Louis' then 'Spirits'
            when full_team_name = 'Portland Trail Blazers' then 'Trail Blazers'
            when full_team_name = 'Providence Steam Rollers' then 'Steam Rollers'
            when full_team_name = 'Sheboygan Red Skins' then 'Red Skins'
            when full_team_name like 'Fort Wayne %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'Golden State %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'Kansas City %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'Los Angeles %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'New Jersey %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'New Orleans/Oklahoma City %' then array_to_string(array_slice(team_name_split, 3, 99), ' ')
            when full_team_name like 'New Orleans %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'New York %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'Oklahoma City %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'San Antonio %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'San Diego %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'San Francisco %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            when full_team_name like 'St. Louis %' then array_to_string(array_slice(team_name_split, 2, 99), ' ')
            else array_to_string(array_slice(team_name_split, 1, 99), ' ')
        end as team_name

    from team_name_original
),

elo_final as (
    select
        cast(a.team_abbrev as string) as team_abbrev,
        cast(a.full_team_name as string) as full_team_name,
        cast(b.team_city as string) as team_city,
        cast(b.team_name as string) as team_name,
        cast(franch as string) as franch,
        safe_cast(a.year as int64) as year,
        safe_cast(gms as int64) as games,
        safe_cast(wins as int64) as wins,
        safe_cast(losses as int64) as losses,

        safe_cast(pf as int64) as points_for,
        safe_cast(pa as int64) as points_against,
        safe_cast(ppg_diff as float64) as points_per_game_diff,

        safe_cast(offense as float64) as offense_rating,
        safe_cast(defense as float64) as defense_rating,

        safe_cast(elo_preseason as float64) as elo_preseason,
        safe_cast(elo_midseason as float64) as elo_midseason,
        safe_cast(end_of_rs as float64) as elo_end_of_regular_season,

        safe_cast(playoffs_won as int64) as playoffs_won,
        safe_cast(playoffs_lost as int64) as playoffs_lost,

        cast(outcome as string) as playoff_outcome,
        safe_cast(po_elo as float64) as playoff_elo,

        cast(coaches as string) as coaches

from {{ source('nba_elo', 'nba_elo_teams_all_time') }} a
join parsed b
    on concat(a.full_team_name,'_',a.year,'_',a.team_abbrev) = b.id
),

joined as (
    select
        case
            when full_team_name = 'New Orleans/Oklahoma City Hornets' then 1610612740
        else k.team_id end as team_id,
        e.*
    from elo_final e
    left join kaggle_team_histories k
        on lower(trim(e.team_city)) = lower(trim(k.team_city))
        and lower(trim(e.team_name)) = lower(trim(k.team_name))
        and e.year - 1 between k.season_founded and k.season_active_till
    qualify row_number() over (
        partition by e.full_team_name, e.year, e.team_abbrev
        order by
            case when trim(e.team_abbrev) = trim(k.team_abbrev) then 0 else 1 end,
            k.season_founded desc
    ) = 1
)

select *
from joined
order by year, full_team_name