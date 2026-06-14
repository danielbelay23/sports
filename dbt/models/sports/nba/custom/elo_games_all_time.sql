{{
    config(
        materialized='view',
    )
}}

with elo as (
    select
        safe_cast(game_id as string) as game_id,
        0 as is_copy,
        safe_cast(season as int64) as year_id,
        safe_cast(date_game as date) as date_game,
        1 as is_playoffs,

        safe_cast(team_id as string) as elo_team_abbrev_raw,
        safe_cast(opp_id as string) as elo_opp_abbrev_raw,

        case
            when team_id = 'CHH' then 'CHA'
            when team_id = 'WSB' then 'WAS'
            else team_id
        end as team_id,

        case
            when opp_id = 'CHH' then 'CHA'
            when opp_id = 'WSB' then 'WAS'
            else opp_id
        end as opp_id,

        case
            when team_id = 'CHH' then 'CHA'
            when team_id = 'WSB' then 'WAS'
            else team_id
        end as fran_id,

        case
            when opp_id = 'CHH' then 'CHA'
            when opp_id = 'WSB' then 'WAS'
            else opp_id
        end as opp_fran,

        safe_cast(home_pts as int64) as pts,
        safe_cast(away_pts as int64) as opp_pts,

        safe_cast(elo_home_po_pre as float64) as elo_i,
        safe_cast(elo_home_po_post as float64) as elo_n,
        safe_cast(elo_away_po_pre as float64) as opp_elo_i,
        safe_cast(elo_away_po_post as float64) as opp_elo_n,

        cast(null as float64) as win_equiv,

        'H' as game_location,

        case
            when home_win = 1 then 'W'
            when home_win = 0 then 'L'
        end as game_result,

        safe_cast(p_home_used as float64) as forecast,

        cast(null as string) as notes

    from {{ ref('stg_nba_all_time_playoffs') }}
    where is_playoff = 1
        and home_pts is not null
        and away_pts is not null
        and p_home_used is not null
),

elo_teams as (
    select
        safe_cast(team_id as int64) as kaggle_team_id,
        upper(trim(cast(team_abbrev as string))) as team_abbrev,
        trim(cast(full_team_name as string)) as full_team_name,
        trim(cast(team_city as string)) as team_city,
        trim(cast(team_name as string)) as team_name,
        trim(cast(franch as string)) as franch,
        safe_cast(year as int64) as year_id
    from {{ ref('stg_nba_elo_teams') }}
),

elo_with_manual_team_ids as (
    select
        elo.*,

        case
            when upper(trim(elo_team_abbrev_raw)) = 'CHA'
                and year_id in (2010, 2014, 2016)
                then 1610612766
            when upper(trim(elo_team_abbrev_raw)) = 'NJN'
                and year_id in (2013, 2014, 2015, 2019, 2020, 2021, 2022, 2023)
                then 1610612751
            when upper(trim(elo_team_abbrev_raw)) = 'NOH'
                and year_id in (1993, 1995, 1997, 1998, 2000, 2001, 2002)
                then 1610612766
            when upper(trim(elo_team_abbrev_raw)) = 'NOH'
                and year_id in (2003, 2004, 2008, 2009, 2011, 2015, 2018, 2022, 2024)
                then 1610612740
            when upper(trim(elo_team_abbrev_raw)) = 'OKC'
                and year_id in (
                    1978, 1979, 1980, 1982, 1983, 1984, 1987, 1988,
                    1989, 1991, 1992, 1993, 1994, 1995, 1996, 1997,
                    1998, 2000, 2002, 2005
                )
                then 1610612760
            when upper(trim(elo_team_abbrev_raw)) = 'SAC'
                and year_id in (1979, 1980, 1981, 1984)
                then 1610612758
            when upper(trim(elo_team_abbrev_raw)) = 'WAS'
                and year_id in (
                    1977, 1978, 1979, 1980, 1982, 1984,
                    1985, 1986, 1987, 1988, 1997
                )
                then 1610612764
        end as manual_kaggle_team_id,

        case
            when upper(trim(elo_opp_abbrev_raw)) = 'CHA'
                and year_id in (2010, 2014, 2016)
                then 1610612766
            when upper(trim(elo_opp_abbrev_raw)) = 'NJN'
                and year_id in (2013, 2014, 2015, 2019, 2020, 2021, 2022, 2023)
                then 1610612751
            when upper(trim(elo_opp_abbrev_raw)) = 'NOH'
                and year_id in (1993, 1995, 1997, 1998, 2000, 2001, 2002)
                then 1610612766
            when upper(trim(elo_opp_abbrev_raw)) = 'NOH'
                and year_id in (2003, 2004, 2008, 2009, 2011, 2015, 2018, 2022, 2024)
                then 1610612740
            when upper(trim(elo_opp_abbrev_raw)) = 'OKC'
                and year_id in (
                    1978, 1979, 1980, 1982, 1983, 1984, 1987, 1988,
                    1989, 1991, 1992, 1993, 1994, 1995, 1996, 1997,
                    1998, 2000, 2002, 2005
                )
                then 1610612760
            when upper(trim(elo_opp_abbrev_raw)) = 'SAC'
                and year_id in (1979, 1980, 1981, 1984)
                then 1610612758
            when upper(trim(elo_opp_abbrev_raw)) = 'WAS'
                and year_id in (
                    1977, 1978, 1979, 1980, 1982, 1984,
                    1985, 1986, 1987, 1988, 1997
                )
                then 1610612764
        end as manual_kaggle_opp_team_id

    from elo
),

team_match as (
    select
        elo.game_id,
        elo.elo_team_abbrev_raw,
        elo.team_id as elo_team_abbrev,
        coalesce(
            elo_teams.kaggle_team_id,
            elo.manual_kaggle_team_id
        ) as kaggle_team_id
    from elo_with_manual_team_ids elo
    left join elo_teams
        on elo.year_id = elo_teams.year_id
        and upper(trim(elo.elo_team_abbrev_raw)) = elo_teams.team_abbrev
    qualify row_number() over (
        partition by elo.game_id, elo.elo_team_abbrev_raw
        order by elo_teams.kaggle_team_id
    ) = 1
),

opp_match as (
    select
        elo.game_id,
        elo.elo_opp_abbrev_raw,
        elo.opp_id as elo_opp_abbrev,
        coalesce(
            elo_teams.kaggle_team_id,
            elo.manual_kaggle_opp_team_id
        ) as kaggle_opp_team_id
    from elo_with_manual_team_ids elo
    left join elo_teams
        on elo.year_id = elo_teams.year_id
        and upper(trim(elo.elo_opp_abbrev_raw)) = elo_teams.team_abbrev
    qualify row_number() over (
        partition by elo.game_id, elo.elo_opp_abbrev_raw
        order by elo_teams.kaggle_team_id
    ) = 1
),

final as (
    select
        elo.* except(
            elo_team_abbrev_raw,
            elo_opp_abbrev_raw,
            manual_kaggle_team_id,
            manual_kaggle_opp_team_id
        ),

        team_match.kaggle_team_id,
        opp_match.kaggle_opp_team_id,
        team_match.kaggle_team_id as kaggle_home_team_id

    from elo_with_manual_team_ids elo

    left join team_match
        on elo.game_id = team_match.game_id
        and elo.elo_team_abbrev_raw = team_match.elo_team_abbrev_raw

    left join opp_match
        on elo.game_id = opp_match.game_id
        and elo.elo_opp_abbrev_raw = opp_match.elo_opp_abbrev_raw
    where elo.year_id >= 1977
)

select *
from final
