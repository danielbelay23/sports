{{
    config(
        materialized='view',
        schema='nba'
    )
}}

select
    `firstName` as first_name,
    `lastName` as last_name,
    `personId` as person_id,
    `gameId` as game_id,
    `gameDateTimeEst` as game_datetime_est,
    `playerteamCity` as player_team_city,
    `playerteamName` as player_team_name,
    `opponentteamCity` as opponent_team_city,
    `opponentteamName` as opponent_team_name,
    `gameType` as game_type,
    case
        when `gameLabel` is null then null
        else replace(`gameLabel`, '- ', '')
    end as game_label,
    cast(case
        when `seriesGameNumber` like "%1%" then "1"
        else `seriesGameNumber` end as float64
    ) as series_game_number,
    `gameSubLabel` as game_sub_label,
    `win` as win,
    `home` as home,
    `numMinutes` as num_minutes,
    `points` as points,
    `assists` as assists,
    `blocks` as blocks,
    `steals` as steals,
    `fieldGoalsAttempted` as field_goals_attempted,
    `fieldGoalsMade` as field_goals_made,
    `fieldGoalsPercentage` as field_goals_percentage,
    `threePointersAttempted` as three_pointers_attempted,
    `threePointersMade` as three_pointers_made,
    `threePointersPercentage` as three_pointers_percentage,
    `freeThrowsAttempted` as free_throws_attempted,
    `freeThrowsMade` as free_throws_made,
    `freeThrowsPercentage` as free_throws_percentage,
    `reboundsDefensive` as rebounds_defensive,
    `reboundsOffensive` as rebounds_offensive,
    `reboundsTotal` as rebounds_total,
    `foulsPersonal` as fouls_personal,
    `turnovers` as turnovers,
    `plusMinusPoints` as plus_minus_points,
    `playerteamId` as player_team_id,
    `opponentteamId` as opponent_team_id,
    `comment` as comment,
    `startingPosition` as starting_position,
    `gameDate` as game_date
from {{ source('nba_raw', 'player_statistics') }}
