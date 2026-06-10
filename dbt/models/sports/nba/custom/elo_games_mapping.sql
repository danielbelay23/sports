{{
    config(
        materialized='view',
        schema='nba'
    )
}}

with elo as (
    select
        * except(team_id, opp_id, is_copy),

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
),

base_player_games as (
    select
        person_id,
        first_name,
        last_name,
        game_id,
        cast(player_team_id as int64) as player_team_id,
        cast(opponent_team_id as int64) as opponent_team_id,
        cast(home as int64) as player_home,
        game_label,
        game_date_time_est,
        cast(game_date_time_est as timestamp) as game_ts,
        date(cast(game_date_time_est as timestamp)) as game_date,
        regexp_replace(
            lower(
                concat(
                    cast(extract(year from cast(game_date_time_est as timestamp)) as string),
                    game_label,
                    cast(
                        least(
                            cast(player_team_id as int64),
                            cast(opponent_team_id as int64)
                        ) as string
                    ),
                    cast(
                        greatest(
                            cast(player_team_id as int64),
                            cast(opponent_team_id as int64)
                        ) as string
                    )
                )
            ),
            r'[^a-z0-9]',
            ''
        ) as series_id,
        safe_cast(regexp_extract(series_game_number, r'\d+') as int64) as series_game_number
    from {{ ref('stg_nba_kaggle_player_statistics') }}
    where game_type = 'Playoffs'
),

player_playoff_games as (
    select
        *,
        min(game_ts) over (partition by person_id, series_id) as series_start_ts
    from base_player_games
),

eligible_players as (
    select
        person_id
    from player_playoff_games
    group by person_id
    having count(distinct series_id) > 10
),

joined as (
    select
        final.*,

        player_playoff_games.person_id,
        player_playoff_games.first_name,
        player_playoff_games.last_name,
        player_playoff_games.game_id as kaggle_game_id,
        player_playoff_games.player_team_id,
        player_playoff_games.opponent_team_id,
        player_playoff_games.player_home,
        case
            when cast(final.kaggle_team_id as int64) = player_playoff_games.player_team_id
                then 'home'
            when cast(final.kaggle_opp_team_id as int64) = player_playoff_games.player_team_id
                then 'away'
        end as player_game_location,
        player_playoff_games.game_label,
        player_playoff_games.game_date_time_est,
        player_playoff_games.game_ts,
        player_playoff_games.series_id,
        player_playoff_games.series_game_number,
        player_playoff_games.series_start_ts

    from final

    left join player_playoff_games
        on final.date_game = player_playoff_games.game_date
        and (
            (
                cast(final.kaggle_team_id as int64) = player_playoff_games.player_team_id
                and cast(final.kaggle_opp_team_id as int64) = player_playoff_games.opponent_team_id
            )
            or (
                cast(final.kaggle_opp_team_id as int64) = player_playoff_games.player_team_id
                and cast(final.kaggle_team_id as int64) = player_playoff_games.opponent_team_id
            )
        )

    inner join eligible_players
        on player_playoff_games.person_id = eligible_players.person_id
)

select
    person_id,
    first_name,
    last_name,
    game_id,
    kaggle_game_id,
    player_team_id,
    opponent_team_id,
    player_home,
    player_game_location,
    kaggle_team_id,
    kaggle_opp_team_id,
    series_id,
    series_game_number,
    game_label,
    year_id,
    date_game,
    fran_id as home_team,
    team_id as home_team_abbrev,
    opp_id as away_team_abbrev,
    opp_fran as away_team,
    game_result as home_win_lose,
    pts as home_pts,
    opp_pts as away_pts,
    elo_i as home_elo_i,
    elo_n as home_elo_n,
    opp_elo_i as away_elo_i,
    opp_elo_n as away_elo_n,
    win_equiv,
    forecast,
    case
        when forecast is null or forecast <= 0 or forecast >= 1 then null
        when forecast >= 0.5 then round(
            -100 * safe_divide(forecast, 1 - forecast) / 5,
            0
        ) * 5
        else round(
            100 * safe_divide(1 - forecast, forecast) / 5,
            0
        ) * 5
    end as forecast_money_line

from joined
