{{
    config(
        materialized='view',
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

raw_player_games as (
    select
        person_id,
        first_name,
        last_name,
        game_id,
        num_minutes,
        points,
        assists,
        rebounds_total,
        blocks,
        steals,
        field_goals_attempted,
        field_goals_made,
        field_goals_percentage,
        turnovers,
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

base_player_games as (
    select
        person_id,
        game_id,
        any_value(first_name) as first_name,
        any_value(last_name) as last_name,
        sum(num_minutes) as num_minutes,
        sum(points) as points,
        sum(assists) as assists,
        sum(rebounds_total) as rebounds_total,
        sum(blocks) as blocks,
        sum(steals) as steals,
        sum(field_goals_attempted) as field_goals_attempted,
        sum(field_goals_made) as field_goals_made,
        safe_divide(
            sum(field_goals_made),
            sum(field_goals_attempted)
        ) as field_goals_percentage,
        sum(turnovers) as turnovers,
        any_value(player_team_id) as player_team_id,
        any_value(opponent_team_id) as opponent_team_id,
        any_value(player_home) as player_home,
        any_value(game_label) as game_label,
        any_value(game_date_time_est) as game_date_time_est,
        any_value(game_ts) as game_ts,
        any_value(game_date) as game_date,
        any_value(series_id) as series_id,
        any_value(series_game_number) as series_game_number
    from raw_player_games
    group by
        person_id,
        game_id
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
        player_playoff_games.num_minutes,
        player_playoff_games.points,
        player_playoff_games.assists,
        player_playoff_games.rebounds_total,
        player_playoff_games.blocks,
        player_playoff_games.steals,
        player_playoff_games.field_goals_attempted,
        player_playoff_games.field_goals_made,
        player_playoff_games.field_goals_percentage,
        player_playoff_games.turnovers,
        case
            when cast(final.kaggle_team_id as int64) = player_playoff_games.player_team_id
                then 'elo_team'
            when cast(final.kaggle_opp_team_id as int64) = player_playoff_games.player_team_id
                then 'elo_opponent'
        end as player_elo_side,
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
),

game_residuals as (
    select
        joined.*,
        case
            when cast(joined.kaggle_team_id as int64) = joined.player_team_id then safe_cast(joined.forecast as float64)
            when cast(joined.kaggle_opp_team_id as int64) = joined.player_team_id then 1 - safe_cast(joined.forecast as float64)
        end as player_game_forecast,
        case
            when joined.forecast is null or joined.forecast <= 0 or joined.forecast >= 1 then null
            when cast(joined.kaggle_team_id as int64) = joined.player_team_id and joined.forecast >= 0.5 then round(
                -100 * safe_divide(joined.forecast, 1 - joined.forecast) / 5,
                0
            ) * 5
            when cast(joined.kaggle_team_id as int64) = joined.player_team_id and joined.forecast < 0.5 then round(
                100 * safe_divide(1 - joined.forecast, joined.forecast) / 5,
                0
            ) * 5
            when cast(joined.kaggle_opp_team_id as int64) = joined.player_team_id and 1 - joined.forecast >= 0.5 then round(
                -100 * safe_divide(1 - joined.forecast, joined.forecast) / 5,
                0
            ) * 5
            when cast(joined.kaggle_opp_team_id as int64) = joined.player_team_id and 1 - joined.forecast < 0.5 then round(
                100 * safe_divide(joined.forecast, 1 - joined.forecast) / 5,
                0
            ) * 5
        end as player_game_money_line,
        case
            when game_result = 'W' then 1
            when game_result = 'L' then 0
        end as elo_team_win,
        case
            when cast(joined.kaggle_team_id as int64) = joined.player_team_id and game_result = 'W' then 1
            when cast(joined.kaggle_team_id as int64) = joined.player_team_id and game_result = 'L' then 0
            when cast(joined.kaggle_opp_team_id as int64) = joined.player_team_id and game_result = 'W' then 0
            when cast(joined.kaggle_opp_team_id as int64) = joined.player_team_id and game_result = 'L' then 1
        end as player_win
    from joined
),

game_residuals_with_diff as (
    select
        game_residuals.*,
        round(
            safe_cast(player_win as float64) - player_game_forecast,
            4
        ) as game_residual
    from game_residuals
),

series_first_games as (
    select
        *
    from game_residuals_with_diff
    qualify row_number() over (
        partition by series_id, player_team_id, opponent_team_id
        order by series_game_number, game_ts, kaggle_game_id
    ) = 1
),

series_format as (
    select
        series_first_games.*,
        case
            when safe_cast(year_id as int64) between 1977 and 1983 and lower(game_label) like '%first%' then 2
            when safe_cast(year_id as int64) between 1984 and 2002 and lower(game_label) like '%first%' then 3
            else 4
        end as required_series_wins,
        case
            when safe_cast(year_id as int64) between 1977 and 1983 and lower(game_label) like '%first%' then ['H', 'A', 'H']
            when safe_cast(year_id as int64) between 1984 and 2002 and lower(game_label) like '%first%' then ['H', 'H', 'A', 'A', 'H']
            when safe_cast(year_id as int64) between 1985 and 2013 and lower(game_label) like '%final%' then ['H', 'H', 'A', 'A', 'A', 'H', 'H']
            else ['H', 'H', 'A', 'A', 'H', 'A', 'H']
        end as home_schedule
    from series_first_games
),

series_game_probabilities as (
    select
        series_format.year_id,
        series_format.series_id,
        series_format.player_team_id,
        series_format.opponent_team_id,
        series_format.series_start_ts,
        series_format.required_series_wins,
        array_length(series_format.home_schedule) as max_series_games,
        game_number,
        case
            when schedule_location = 'H' and series_format.player_home = 1 then player_game_forecast
            when schedule_location = 'A' and series_format.player_home = 0 then player_game_forecast
            when schedule_location = 'H' and series_format.player_home = 0 then 1 - player_game_forecast
            when schedule_location = 'A' and series_format.player_home = 1 then 1 - player_game_forecast
        end as scheduled_player_game_forecast
    from series_format,
        unnest(home_schedule) as schedule_location with offset game_offset
    cross join unnest([game_offset + 1]) as game_number
),

series_path_steps as (
    select
        series_game_probabilities.year_id,
        series_game_probabilities.series_id,
        series_game_probabilities.player_team_id,
        series_game_probabilities.opponent_team_id,
        series_game_probabilities.series_start_ts,
        series_game_probabilities.required_series_wins,
        series_game_probabilities.max_series_games,
        series_game_probabilities.game_number,
        path_number,
        mod(
            div(
                path_number,
                cast(pow(2, series_game_probabilities.max_series_games - series_game_probabilities.game_number) as int64)
            ),
            2
        ) as player_win_bit,
        series_game_probabilities.scheduled_player_game_forecast
    from series_game_probabilities
    cross join unnest(
        generate_array(
            0,
            cast(pow(2, series_game_probabilities.max_series_games) as int64) - 1
        )
    ) as path_number
),

series_path_steps_with_running as (
    select
        series_path_steps.*,
        sum(player_win_bit) over (
            partition by series_id, player_team_id, opponent_team_id, path_number
            order by game_number
            rows between unbounded preceding and current row
        ) as running_player_wins,
        sum(1 - player_win_bit) over (
            partition by series_id, player_team_id, opponent_team_id, path_number
            order by game_number
            rows between unbounded preceding and current row
        ) as running_opponent_wins
    from series_path_steps
),

series_paths as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        required_series_wins,
        path_number,
        exp(sum(ln(
            case
                when player_win_bit = 1 then scheduled_player_game_forecast
                else 1 - scheduled_player_game_forecast
            end
        ))) as path_probability,
        sum(player_win_bit) as player_wins,
        sum(1 - player_win_bit) as opponent_wins,
        min(
            case
                when running_player_wins = required_series_wins
                    and running_opponent_wins < required_series_wins
                    then game_number
            end
        ) as player_clinch_game,
        min(
            case
                when running_opponent_wins = required_series_wins
                    and running_player_wins < required_series_wins
                    then game_number
            end
        ) as opponent_clinch_game
    from series_path_steps_with_running
    group by
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        required_series_wins,
        path_number
),

series_odds as (
    select
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts,
        sum(
            case
                when player_clinch_game is not null
                    and (opponent_clinch_game is null or player_clinch_game < opponent_clinch_game)
                    then path_probability
                else 0
            end
        ) as series_forecast
    from series_paths
    where player_clinch_game is not null
        or opponent_clinch_game is not null
    group by
        year_id,
        series_id,
        player_team_id,
        opponent_team_id,
        series_start_ts
),

series_results as (
    select
        series_id,
        player_team_id,
        opponent_team_id,
        safe_cast(year_id as int64) as year_id,
        min(series_start_ts) as series_start_ts,
        count(distinct kaggle_game_id) as team_series_games,
        sum(player_win) as team_series_wins,
        sum(1 - player_win) as opponent_series_wins,
        case
            when sum(player_win) > sum(1 - player_win) then 1
            when sum(player_win) < sum(1 - player_win) then 0
        end as series_win
    from (
        select distinct
            series_id,
            kaggle_game_id,
            player_team_id,
            opponent_team_id,
            safe_cast(year_id as int64) as year_id,
            series_start_ts,
            player_win
        from game_residuals_with_diff
    )
    group by
        series_id,
        player_team_id,
        opponent_team_id,
        year_id
),

series_residuals as (
    select
        series_results.year_id,
        series_results.series_id,
        series_results.player_team_id,
        series_results.opponent_team_id,
        series_results.series_start_ts,
        series_results.team_series_games,
        series_results.team_series_wins,
        series_results.opponent_series_wins,
        series_results.series_win,
        series_odds.series_forecast,
        case
            when series_odds.series_forecast is null
                or series_odds.series_forecast <= 0
                or series_odds.series_forecast >= 1 then null
            when series_odds.series_forecast >= 0.5 then round(
                -100 * safe_divide(series_odds.series_forecast, 1 - series_odds.series_forecast) / 5,
                0
            ) * 5
            else round(
                100 * safe_divide(1 - series_odds.series_forecast, series_odds.series_forecast) / 5,
                0
            ) * 5
        end as series_money_line,
        round(
            safe_cast(series_results.series_win as float64)
            - series_odds.series_forecast,
            4
        ) as series_residual
    from series_results
    left join series_odds
        on series_results.series_id = series_odds.series_id
        and series_results.player_team_id = series_odds.player_team_id
        and series_results.opponent_team_id = series_odds.opponent_team_id
        and series_results.year_id = series_odds.year_id
),

player_series_residuals as (
    select distinct
        game_residuals_with_diff.person_id,
        series_residuals.year_id,
        series_residuals.series_id,
        series_residuals.player_team_id,
        series_residuals.opponent_team_id,
        series_residuals.series_start_ts,
        series_residuals.team_series_games,
        series_residuals.team_series_wins,
        series_residuals.opponent_series_wins,
        series_residuals.series_win,
        series_residuals.series_forecast,
        series_residuals.series_money_line,
        series_residuals.series_residual
    from game_residuals_with_diff
    inner join series_residuals
        on game_residuals_with_diff.series_id = series_residuals.series_id
        and game_residuals_with_diff.player_team_id = series_residuals.player_team_id
        and game_residuals_with_diff.opponent_team_id = series_residuals.opponent_team_id
        and safe_cast(game_residuals_with_diff.year_id as int64) = series_residuals.year_id
),

series_residuals_with_running as (
    select
        player_series_residuals.*,
        round(
            sum(series_residual) over (
                partition by person_id
                order by series_start_ts, series_id
                rows between unbounded preceding and current row
            ),
            4
        ) as career_series_running_residual
    from player_series_residuals
),

series_career_bounds as (
    select
        person_id,
        array_agg(
            career_series_running_residual ignore nulls
            order by series_start_ts desc, series_id desc
            limit 1
        )[safe_offset(0)] as career_series_last_cumulative_residual,
        max(career_series_running_residual) as career_series_max_cumulative_residual
    from series_residuals_with_running
    group by person_id
),

game_residuals_with_running as (
    select
        game_residuals_with_diff.*,
        round(
            sum(game_residual) over (
                partition by person_id
                order by game_ts, kaggle_game_id
                rows between unbounded preceding and current row
            ),
            4
        ) as career_game_running_residual
    from game_residuals_with_diff
),

game_career_bounds as (
    select
        person_id,
        array_agg(
            career_game_running_residual ignore nulls
            order by game_ts desc, kaggle_game_id desc
            limit 1
        )[safe_offset(0)] as career_game_last_cumulative_residual,
        max(career_game_running_residual) as career_game_max_cumulative_residual
    from game_residuals_with_running
    group by person_id
),

year_residuals as (
    select
        game_residuals_with_running.person_id,
        safe_cast(game_residuals_with_running.year_id as int64) as year_id,
        round(sum(game_residuals_with_running.game_residual), 4) as year_game_residual
    from game_residuals_with_running
    group by
        game_residuals_with_running.person_id,
        safe_cast(game_residuals_with_running.year_id as int64)
),

year_series_residuals as (
    select
        player_series_residuals.person_id,
        player_series_residuals.year_id,
        round(sum(player_series_residuals.series_residual), 4) as year_series_residual
    from player_series_residuals
    group by
        player_series_residuals.person_id,
        player_series_residuals.year_id
),

year_residuals_with_running as (
    select
        year_residuals.person_id,
        year_residuals.year_id,
        year_residuals.year_game_residual,
        coalesce(year_series_residuals.year_series_residual, 0) as year_series_residual,
        round(
            sum(year_residuals.year_game_residual) over (
                partition by year_residuals.person_id
                order by year_residuals.year_id
                rows between unbounded preceding and current row
            ),
            4
        ) as career_year_game_running_residual,
        round(
            sum(coalesce(year_series_residuals.year_series_residual, 0)) over (
                partition by year_residuals.person_id
                order by year_residuals.year_id
                rows between unbounded preceding and current row
            ),
            4
        ) as career_year_series_running_residual
    from year_residuals
    left join year_series_residuals
        on year_residuals.person_id = year_series_residuals.person_id
        and year_residuals.year_id = year_series_residuals.year_id
),

year_career_bounds as (
    select
        person_id,
        array_agg(
            career_year_game_running_residual ignore nulls
            order by year_id desc
            limit 1
        )[safe_offset(0)] as career_year_game_last_cumulative_residual,
        array_agg(
            career_year_series_running_residual ignore nulls
            order by year_id desc
            limit 1
        )[safe_offset(0)] as career_year_series_last_cumulative_residual,
        max(career_year_game_running_residual) as career_year_game_max_cumulative_residual,
        max(career_year_series_running_residual) as career_year_series_max_cumulative_residual
    from year_residuals_with_running
    group by person_id
)

select
    game_residuals_with_running.person_id,
    game_residuals_with_running.first_name,
    game_residuals_with_running.last_name,
    game_residuals_with_running.game_id,
    game_residuals_with_running.kaggle_game_id,
    game_residuals_with_running.player_team_id,
    game_residuals_with_running.opponent_team_id,
    game_residuals_with_running.player_home,
    game_residuals_with_running.player_elo_side,
    game_residuals_with_running.kaggle_team_id,
    game_residuals_with_running.kaggle_opp_team_id,
    game_residuals_with_running.series_id,
    game_residuals_with_running.series_game_number,
    game_residuals_with_running.game_label,
    game_residuals_with_running.year_id,
    game_residuals_with_running.date_game,
    game_residuals_with_running.num_minutes,
    game_residuals_with_running.points,
    game_residuals_with_running.assists,
    game_residuals_with_running.rebounds_total,
    game_residuals_with_running.blocks,
    game_residuals_with_running.steals,
    game_residuals_with_running.field_goals_attempted,
    game_residuals_with_running.field_goals_made,
    game_residuals_with_running.field_goals_percentage,
    game_residuals_with_running.turnovers,
    game_residuals_with_running.fran_id as elo_team,
    game_residuals_with_running.team_id as elo_team_abbrev,
    game_residuals_with_running.opp_id as elo_opponent_abbrev,
    game_residuals_with_running.opp_fran as elo_opponent,
    game_residuals_with_running.game_result as elo_team_win_lose,
    game_residuals_with_running.pts as elo_team_pts,
    game_residuals_with_running.opp_pts as elo_opponent_pts,
    game_residuals_with_running.elo_i as elo_team_elo_i,
    game_residuals_with_running.elo_n as elo_team_elo_n,
    game_residuals_with_running.opp_elo_i as elo_opponent_elo_i,
    game_residuals_with_running.opp_elo_n as elo_opponent_elo_n,
    game_residuals_with_running.win_equiv,
    game_residuals_with_running.forecast,
    case
        when game_residuals_with_running.forecast is null
            or game_residuals_with_running.forecast <= 0
            or game_residuals_with_running.forecast >= 1 then null
        when game_residuals_with_running.forecast >= 0.5 then round(
            -100 * safe_divide(
                game_residuals_with_running.forecast,
                1 - game_residuals_with_running.forecast
            ) / 5,
            0
        ) * 5
        else round(
            100 * safe_divide(
                1 - game_residuals_with_running.forecast,
                game_residuals_with_running.forecast
            ) / 5,
            0
        ) * 5
    end as forecast_money_line,
    game_residuals_with_running.player_game_forecast,
    game_residuals_with_running.player_game_money_line,
    game_residuals_with_running.player_win,
    game_residuals_with_running.game_residual,
    game_career_bounds.career_game_last_cumulative_residual,
    game_career_bounds.career_game_max_cumulative_residual,
    game_residuals_with_running.career_game_running_residual,
    series_residuals_with_running.team_series_wins,
    series_residuals_with_running.opponent_series_wins,
    series_residuals_with_running.series_forecast,
    series_residuals_with_running.series_money_line,
    series_residuals_with_running.series_win,
    series_residuals_with_running.series_residual,
    series_residuals_with_running.career_series_running_residual,
    series_career_bounds.career_series_last_cumulative_residual,
    series_career_bounds.career_series_max_cumulative_residual,
    year_residuals_with_running.year_game_residual,
    year_residuals_with_running.year_series_residual,
    year_residuals_with_running.career_year_game_running_residual,
    year_residuals_with_running.career_year_series_running_residual,
    year_career_bounds.career_year_game_last_cumulative_residual,
    year_career_bounds.career_year_series_last_cumulative_residual,
    year_career_bounds.career_year_game_max_cumulative_residual,
    year_career_bounds.career_year_series_max_cumulative_residual

from game_residuals_with_running

left join game_career_bounds
    on game_residuals_with_running.person_id = game_career_bounds.person_id

left join series_residuals_with_running
    on game_residuals_with_running.person_id = series_residuals_with_running.person_id
    and game_residuals_with_running.series_id = series_residuals_with_running.series_id
    and game_residuals_with_running.player_team_id = series_residuals_with_running.player_team_id
    and game_residuals_with_running.opponent_team_id = series_residuals_with_running.opponent_team_id

left join series_career_bounds
    on game_residuals_with_running.person_id = series_career_bounds.person_id

left join year_residuals_with_running
    on game_residuals_with_running.person_id = year_residuals_with_running.person_id
    and safe_cast(game_residuals_with_running.year_id as int64) = year_residuals_with_running.year_id

left join year_career_bounds
    on game_residuals_with_running.person_id = year_career_bounds.person_id
