--nba_custom_implied_odds_games
/*
  -- get average odds for the home/away team
  -- get average odds for the away team
  -- convert odds to implied win probabilities
  -- create a unique series id (year + round + team a + team b)
  -- identify players with more than 10 playoff series
  -- bring it all together to calculate the residuals
*/

with team_odds as (
  select
    game_id,
    team_id as target_team_id,
    avg(price1) as avg_price
  from `dbt_nba.nba_betting_spread`
  group by 1, 2

  union all

  select
    game_id,
    a_team_id as target_team_id,
    avg(price2) as avg_price
  from `dbt_nba.nba_betting_spread`
  group by 1, 2
),

implied_probs as (
  select
    game_id,
    target_team_id,
    avg_price,
    case
      when avg_price < 0 then abs(avg_price) / (abs(avg_price) + 100.0)
      else 100.0 / (avg_price + 100.0)
    end as implied_win_prob
  from team_odds
),

base_player_games as (
  select
    person_id,
    first_name,
    last_name,
    game_id,
    cast(player_team_id as int64) as player_team_id,
    cast(opponent_team_id as int64) as opponent_team_id,
    game_label,
    game_datetime_est,
    cast(game_datetime_est as timestamp) as game_ts,
    regexp_replace(
      lower(
        concat(
          cast(extract(year from cast(game_datetime_est as timestamp)) as string),
          game_label,
          cast(least(cast(player_team_id as int64), cast(opponent_team_id as int64)) as string),
          cast(greatest(cast(player_team_id as int64), cast(opponent_team_id as int64)) as string)
        )
      ), 
      r'[^a-z0-9]', 
      ''
    ) as series_id,
    cast(cast(series_game_number as float64) as int64) as series_game_number
  from `dbt_nba.nba_kaggle_player_statistics`
  where game_type = 'Playoffs'
),

player_playoff_games as (
  -- calculate the start date of each series to group the games together for the window function
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

sub_final as (
  select
    p.person_id,
    p.first_name,
    p.last_name,
    p.series_id,
    p.series_game_number,
    p.game_id,
    p.game_datetime_est,
    t.win,
    round(o.implied_win_prob, 4) as implied_win_prob,
    round(cast(t.win as float64) - o.implied_win_prob, 4) as game_residual,
    
    -- 1. running total of game residuals--> so accumulating game-by-game across the whole career
    round(
      sum(cast(t.win as float64) - o.implied_win_prob)
        over (
          partition by p.person_id
          order by p.game_ts
        ),
      4
    ) as cumulative_career_game_residual,

    -- 2. running total of game residuals accumulated---> so at the series level (sum)
    round(
      sum(cast(t.win as float64) - o.implied_win_prob)
        over (
          partition by p.person_id, series_id
          order by p.series_start_ts
        ),
      4
    ) as cumulative_series_residual,

    -- 3. average game residuals of a series---> so at the series level (average)
    round(
      avg(cast(t.win as float64) - o.implied_win_prob)
        over (
          partition by p.person_id, series_id
          order by p.series_start_ts
        ),
      4
    ) as average_series_residual,

    dense_rank() over (
      partition by p.person_id 
      order by p.series_start_ts
    ) as player_series_order

  from player_playoff_games p
  inner join eligible_players e
    on p.person_id = e.person_id
  inner join `dbt_nba.nba_kaggle_team_statistics` t
    on cast(p.game_id as int64) = t.game_id
    and p.player_team_id = t.team_id
  left join implied_probs o
    on cast(p.game_id as int64) = o.game_id
    and p.player_team_id = o.target_team_id
  ),

max_career_residual as (
  select 
    person_id, 
    first_name,
    last_name,
    max(cumulative_career_game_residual) as max_cumulative_career_game_residual
  from sub_final
  group by 1,2,3
  order by max_cumulative_career_game_residual desc
),

final as (
  select 
    a.*,
    b.max_cumulative_career_game_residual
  from sub_final a
  join max_career_residual b
    on a.person_id = b.person_id
  where implied_win_prob is not null
    and game_residual is not null
    and cumulative_career_game_residual is not null
    and cumulative_series_residual is not null
)

select 
  *
from final
order by max_cumulative_career_game_residual desc, 
  player_series_order desc, 
  series_game_number desc
