/*
  -- get average odds for the home/away team
  -- get average odds for the away team
  -- convert odds to implied win probabilities
  -- create a unique series id (year + round + team a + team b)
  -- identify players with more than 10 playoff series
  -- calculate game-level residuals
  -- aggregate residuals to the series level
  -- calculate the cumulative sum and average across the player's series order
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
    ) as series_id
  from `dbt_nba.nba_kaggle_player_statistics`
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

game_residuals as (
  -- calculate the residual for each individual game first
  select
    p.person_id,
    p.first_name,
    p.last_name,
    p.series_id,
    p.series_start_ts,
    cast(t.win as float64) - o.implied_win_prob as game_residual
  from player_playoff_games p
  inner join eligible_players e
    on p.person_id = e.person_id
  inner join `dbt_nba.nba_kaggle_team_statistics` t
    on cast(p.game_id as int64) = t.game_id
    and p.player_team_id = t.team_id
  left join implied_probs o
    on cast(p.game_id as int64) = o.game_id
    and p.player_team_id = o.target_team_id
  where o.implied_win_prob is not null
    and t.win is not null
),

series_summary as (
  -- roll up the game residuals to 1 row per series
  select
    person_id,
    first_name,
    last_name,
    series_id,
    series_start_ts,
    sum(game_residual) as series_sum_residual,
    avg(game_residual) as series_avg_residual
  from game_residuals
  group by 1, 2, 3, 4, 5
),

series_ordered as (
  -- establish the chronological order of series for each player
  select
    *,
    dense_rank() over (partition by person_id order by series_start_ts) as player_series_order
  from series_summary
),

cumulative_series as (
  -- calculate the running total and running average across the player's series
  select
    person_id,
    first_name,
    last_name,
    series_id,
    player_series_order,
    series_sum_residual,
    series_avg_residual,
    sum(series_sum_residual) over (
      partition by person_id 
      order by player_series_order
    ) as cumulative_sum_series_residual,
    avg(series_avg_residual) over (
      partition by person_id 
      order by player_series_order
    ) as cumulative_avg_series_residual
  from series_ordered
),

max_career_residual as (
  -- find the player's peak cumulative sum for sorting purposes
  select 
    person_id,
    max(cumulative_sum_series_residual) as max_cumulative_career_residual
  from cumulative_series
  group by 1
)

select 
  c.first_name,
  c.last_name,
  c.series_id,
  c.player_series_order,
  round(c.series_sum_residual, 4) as series_sum_residual,
  round(c.series_avg_residual, 4) as series_avg_residual,
  round(c.cumulative_sum_series_residual, 4) as cumulative_sum_series_residual,
  round(c.cumulative_avg_series_residual, 4) as cumulative_avg_series_residual,
  round(max_cumulative_career_residual, 4) as max_career_residual
from cumulative_series c
join max_career_residual m
  on c.person_id = m.person_id
order by 
  m.max_cumulative_career_residual desc, 
  c.player_series_order desc