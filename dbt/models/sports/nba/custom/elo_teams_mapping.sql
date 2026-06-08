{{
    config(
        materialized='view'
    )
}}


with elo as (
    select
        * except(team_id, opp_id, notes, is_copy),

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
            when upper(trim(fran_id)) = 'PELICANS'
                and safe_cast(year_id as int64) < 2014
                then 'HORNETS'
            else upper(trim(fran_id))
        end as fran_id_join,

        case
            when upper(trim(opp_fran)) = 'PELICANS'
                and safe_cast(year_id as int64) < 2014
                then 'HORNETS'
            else upper(trim(opp_fran))
        end as opp_fran_join

    from {{ ref('stg_nba_elo_playoffs_post_1977') }}
    where is_copy = 0
),

team_histories as (
    select
        team_id,
        upper(trim(team_abbrev)) as team_abbreviation,
        upper(trim(team_name)) as team_name,
        safe_cast(season_founded as int64) as season_founded,
        coalesce(safe_cast(season_active_till as int64), 2100) as season_active_till
    from {{ ref('stg_nba_kaggle_team_histories') }}
    where league = 'NBA'
        and coalesce(safe_cast(season_active_till as int64), 2100) >= 1970
),

team_abbrev_match as (
    select
        elo.game_id,
        elo.team_id as elo_team_id,
        team_histories.team_id as kaggle_team_id
    from elo
    left join team_histories
        on upper(trim(elo.team_id)) = team_histories.team_abbreviation
        and safe_cast(elo.year_id as int64)
            between team_histories.season_founded and team_histories.season_active_till
),

team_fran_match as (
    select
        elo.game_id,
        elo.team_id as elo_team_id,
        team_histories.team_id as kaggle_team_id
    from elo
    left join team_histories
        on elo.fran_id_join = team_histories.team_name
        and safe_cast(elo.year_id as int64)
            between team_histories.season_founded and team_histories.season_active_till
),

opp_abbrev_match as (
    select
        elo.game_id,
        elo.opp_id as elo_opp_id,
        team_histories.team_id as kaggle_opp_team_id
    from elo
    left join team_histories
        on upper(trim(elo.opp_id)) = team_histories.team_abbreviation
        and safe_cast(elo.year_id as int64)
            between team_histories.season_founded and team_histories.season_active_till
),

opp_fran_match as (
    select
        elo.game_id,
        elo.opp_id as elo_opp_id,
        team_histories.team_id as kaggle_opp_team_id
    from elo
    left join team_histories
        on elo.opp_fran_join = team_histories.team_name
        and safe_cast(elo.year_id as int64)
            between team_histories.season_founded and team_histories.season_active_till
),

final as (
    select
        elo.* except(fran_id_join, opp_fran_join),

        coalesce(
            team_abbrev_match.kaggle_team_id,
            team_fran_match.kaggle_team_id
        ) as kaggle_team_id,

        coalesce(
            opp_abbrev_match.kaggle_opp_team_id,
            opp_fran_match.kaggle_opp_team_id
        ) as kaggle_opp_team_id,

        case
            when elo.game_location = 'H' then coalesce(
                team_abbrev_match.kaggle_team_id,
                team_fran_match.kaggle_team_id
            )
            when elo.game_location = 'A' then coalesce(
                opp_abbrev_match.kaggle_opp_team_id,
                opp_fran_match.kaggle_opp_team_id
            )
        end as kaggle_home_team_id

    from elo

    left join team_abbrev_match
        on elo.game_id = team_abbrev_match.game_id
        and elo.team_id = team_abbrev_match.elo_team_id

    left join team_fran_match
        on elo.game_id = team_fran_match.game_id
        and elo.team_id = team_fran_match.elo_team_id
        and team_abbrev_match.kaggle_team_id is null

    left join opp_abbrev_match
        on elo.game_id = opp_abbrev_match.game_id
        and elo.opp_id = opp_abbrev_match.elo_opp_id

    left join opp_fran_match
        on elo.game_id = opp_fran_match.game_id
        and elo.opp_id = opp_fran_match.elo_opp_id
        and opp_abbrev_match.kaggle_opp_team_id is null
)

select
    *
from final
