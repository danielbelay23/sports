/*
  -- get average odds for the home/away team
  -- get average odds for the away team
  -- convert odds to implied win probabilities
  -- create a unique series ID (year + round + team A + team B)
  -- identify players with more than 10 playoff series
  -- bring it all together to calculate the cumulative residual at the game level
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

player_playoff_games as (
  select
    person_id,
    first_name,
    last_name,
    game_id,
    cast(player_team_id as int64) as player_team_id,
    cast(opponent_team_id as int64) as opponent_team_id,
    game_label,
    game_datetime_est,
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

eligible_players as (
  select
    person_id
  from player_playoff_games
  group by person_id
  having count(distinct series_id) > 10
),

final as (
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
    round(
      sum(cast(t.win as float64) - o.implied_win_prob)
        over (
          partition by p.person_id, p.series_id
          order by cast(p.game_datetime_est as timestamp)
        ),
      4
    ) as cumulative_series_residual,
    dense_rank() over (
      partition by p.person_id
      order by substr(p.series_id, 1, 4), p.series_id
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
  order by
    p.last_name,
    p.first_name,
    p.series_id,
    cast(p.game_datetime_est as timestamp)
)

select *
from final
where implied_win_prob is not null
  and game_residual is not null
  and cumulative_series_residual is not null
