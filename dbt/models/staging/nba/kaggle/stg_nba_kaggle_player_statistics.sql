-- {{ config(materialized='table') }}

-- select
--     safe_cast(`firstName` as string) as first_name,
--     safe_cast(`lastName` as string) as last_name,
--     safe_cast(round(safe_cast(`personId` as float64)) as int64) as person_id,
--     safe_cast(round(safe_cast(`gameId` as float64)) as int64) as game_id,
--     safe_cast(`gameDateTimeEst` as timestamp) as game_date_time_est,
--     safe_cast(`playerteamCity` as string) as player_team_city,
--     safe_cast(`playerteamName` as string) as player_team_name,
--     safe_cast(`opponentteamCity` as string) as opponent_team_city,
--     safe_cast(`opponentteamName` as string) as opponent_team_name,
--     safe_cast(`gameType` as string) as game_type,
--     safe_cast(`gameLabel` as string) as game_label,
--     safe_cast(`seriesGameNumber` as string) as series_game_number,
--     safe_cast(`gameSubLabel` as string) as game_sub_label,
--     safe_cast(round(safe_cast(`win` as float64)) as int64) as win,
--     safe_cast(round(safe_cast(`home` as float64)) as int64) as home,
--     safe_cast(`numMinutes` as float64) as num_minutes,
--     safe_cast(round(safe_cast(`points` as float64)) as int64) as points,
--     safe_cast(round(safe_cast(`assists` as float64)) as int64) as assists,
--     safe_cast(round(safe_cast(`blocks` as float64)) as int64) as blocks,
--     safe_cast(round(safe_cast(`steals` as float64)) as int64) as steals,
--     safe_cast(round(safe_cast(`fieldGoalsAttempted` as float64)) as int64) as field_goals_attempted,
--     safe_cast(round(safe_cast(`fieldGoalsMade` as float64)) as int64) as field_goals_made,
--     safe_cast(`fieldGoalsPercentage` as float64) as field_goals_percentage,
--     safe_cast(round(safe_cast(`threePointersAttempted` as float64)) as int64) as three_pointers_attempted,
--     safe_cast(round(safe_cast(`threePointersMade` as float64)) as int64) as three_pointers_made,
--     safe_cast(`threePointersPercentage` as float64) as three_pointers_percentage,
--     safe_cast(round(safe_cast(`freeThrowsAttempted` as float64)) as int64) as free_throws_attempted,
--     safe_cast(round(safe_cast(`freeThrowsMade` as float64)) as int64) as free_throws_made,
--     safe_cast(`freeThrowsPercentage` as float64) as free_throws_percentage,
--     safe_cast(round(safe_cast(`reboundsDefensive` as float64)) as int64) as rebounds_defensive,
--     safe_cast(round(safe_cast(`reboundsOffensive` as float64)) as int64) as rebounds_offensive,
--     safe_cast(round(safe_cast(`reboundsTotal` as float64)) as int64) as rebounds_total,
--     safe_cast(round(safe_cast(`foulsPersonal` as float64)) as int64) as fouls_personal,
--     safe_cast(round(safe_cast(`turnovers` as float64)) as int64) as turnovers,
--     safe_cast(round(safe_cast(replace(`plusMinusPoints`, '+', '') as float64)) as int64) as plus_minus_points,
--     safe_cast(round(safe_cast(`playerteamId` as float64)) as int64) as player_team_id,
--     safe_cast(round(safe_cast(`opponentteamId` as float64)) as int64) as opponent_team_id,
--     safe_cast(`comment` as string) as comment,
--     safe_cast(`startingPosition` as string) as starting_position,
--     safe_cast(`gameDate` as date) as game_date
-- from {{ source('nba_raw', 'player_statistics') }}

{{ config(materialized='table') }}

with player_statistics as (
    select
        safe_cast(`firstName` as string) as first_name,
        safe_cast(`lastName` as string) as last_name,
        safe_cast(round(safe_cast(`personId` as float64)) as int64) as person_id,
        safe_cast(round(safe_cast(`gameId` as float64)) as int64) as game_id,
        safe_cast(`gameDateTimeEst` as timestamp) as game_date_time_est,

        safe_cast(`playerteamCity` as string) as player_team_city,
        safe_cast(`playerteamName` as string) as player_team_name,
        safe_cast(`opponentteamCity` as string) as opponent_team_city,
        safe_cast(`opponentteamName` as string) as opponent_team_name,

        safe_cast(`gameType` as string) as game_type,
        safe_cast(`gameLabel` as string) as game_label,
        safe_cast(`seriesGameNumber` as string) as series_game_number,
        safe_cast(`gameSubLabel` as string) as game_sub_label,

        safe_cast(round(safe_cast(`win` as float64)) as int64) as win,
        safe_cast(round(safe_cast(`home` as float64)) as int64) as home,

        safe_cast(`numMinutes` as float64) as num_minutes,

        safe_cast(round(safe_cast(`points` as float64)) as int64) as points,
        safe_cast(round(safe_cast(`assists` as float64)) as int64) as assists,
        safe_cast(round(safe_cast(`blocks` as float64)) as int64) as blocks,
        safe_cast(round(safe_cast(`steals` as float64)) as int64) as steals,

        safe_cast(round(safe_cast(`fieldGoalsAttempted` as float64)) as int64) as field_goals_attempted,
        safe_cast(round(safe_cast(`fieldGoalsMade` as float64)) as int64) as field_goals_made,
        safe_cast(`fieldGoalsPercentage` as float64) as field_goals_percentage,

        safe_cast(round(safe_cast(`threePointersAttempted` as float64)) as int64) as three_pointers_attempted,
        safe_cast(round(safe_cast(`threePointersMade` as float64)) as int64) as three_pointers_made,
        safe_cast(`threePointersPercentage` as float64) as three_pointers_percentage,

        safe_cast(round(safe_cast(`freeThrowsAttempted` as float64)) as int64) as free_throws_attempted,
        safe_cast(round(safe_cast(`freeThrowsMade` as float64)) as int64) as free_throws_made,
        safe_cast(`freeThrowsPercentage` as float64) as free_throws_percentage,

        safe_cast(round(safe_cast(`reboundsDefensive` as float64)) as int64) as rebounds_defensive,
        safe_cast(round(safe_cast(`reboundsOffensive` as float64)) as int64) as rebounds_offensive,
        safe_cast(round(safe_cast(`reboundsTotal` as float64)) as int64) as rebounds_total,

        safe_cast(round(safe_cast(`foulsPersonal` as float64)) as int64) as fouls_personal,
        safe_cast(round(safe_cast(`turnovers` as float64)) as int64) as turnovers,
        safe_cast(round(safe_cast(replace(`plusMinusPoints`, '+', '') as float64)) as int64) as plus_minus_points,

        safe_cast(round(safe_cast(`playerteamId` as float64)) as int64) as player_team_id_raw,
        safe_cast(round(safe_cast(`opponentteamId` as float64)) as int64) as opponent_team_id_raw,

        safe_cast(`comment` as string) as comment,
        safe_cast(`startingPosition` as string) as starting_position,
        safe_cast(`gameDate` as date) as game_date

    from {{ source('nba_raw', 'player_statistics') }}
),

team_histories as (
    select
        team_id,
        lower(trim(team_city)) as team_city_join,
        lower(trim(team_name)) as team_name_join,
        season_founded,
        season_active_till
    from {{ ref('stg_nba_kaggle_team_histories') }}
    where league = 'NBA'
),

final as (
    select
        player_statistics.first_name,
        player_statistics.last_name,
        player_statistics.person_id,
        player_statistics.game_id,
        player_statistics.game_date_time_est,

        player_statistics.player_team_city,
        player_statistics.player_team_name,
        player_statistics.opponent_team_city,
        player_statistics.opponent_team_name,

        player_statistics.game_type,
        player_statistics.game_label,
        player_statistics.series_game_number,
        player_statistics.game_sub_label,

        player_statistics.win,
        player_statistics.home,
        player_statistics.num_minutes,

        player_statistics.points,
        player_statistics.assists,
        player_statistics.blocks,
        player_statistics.steals,

        player_statistics.field_goals_attempted,
        player_statistics.field_goals_made,
        player_statistics.field_goals_percentage,

        player_statistics.three_pointers_attempted,
        player_statistics.three_pointers_made,
        player_statistics.three_pointers_percentage,

        player_statistics.free_throws_attempted,
        player_statistics.free_throws_made,
        player_statistics.free_throws_percentage,

        player_statistics.rebounds_defensive,
        player_statistics.rebounds_offensive,
        player_statistics.rebounds_total,

        player_statistics.fouls_personal,
        player_statistics.turnovers,
        player_statistics.plus_minus_points,

        coalesce(
            player_statistics.player_team_id_raw,
            player_team_history.team_id
        ) as player_team_id,

        coalesce(
            player_statistics.opponent_team_id_raw,
            opponent_team_history.team_id
        ) as opponent_team_id,

        player_statistics.comment,
        player_statistics.starting_position,
        player_statistics.game_date

    from player_statistics

    left join team_histories as player_team_history
        on player_statistics.player_team_id_raw is null
        and lower(trim(player_statistics.player_team_city)) = player_team_history.team_city_join
        and lower(trim(player_statistics.player_team_name)) = player_team_history.team_name_join
        and extract(year from player_statistics.game_date_time_est) between player_team_history.season_founded and player_team_history.season_active_till

    left join team_histories as opponent_team_history
        on player_statistics.opponent_team_id_raw is null
        and lower(trim(player_statistics.opponent_team_city)) = opponent_team_history.team_city_join
        and lower(trim(player_statistics.opponent_team_name)) = opponent_team_history.team_name_join
        and extract(year from player_statistics.game_date_time_est) between opponent_team_history.season_founded and opponent_team_history.season_active_till
)

select *
from final