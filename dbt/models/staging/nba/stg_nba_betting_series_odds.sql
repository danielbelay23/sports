select
  cast(`year` as int64) as `year`,
  cast(`conference` as string) as `conference`,
  cast(`round` as string) as `round`,
  cast(`home_team` as string) as `home_team`,
  cast(`home_seed` as int64) as `home_seed`,
  if( `home_odds` = "N/A", null, safe_cast(`home_odds` as float64)) as `home_odds`,
  cast(`away_team` as string) as `away_team`,
  cast(`away_seed` as int64) as `away_seed`,
  if( `away_odds` = "N/A", null, safe_cast(`away_odds` as float64)) as `away_odds`,
  cast(`winner` as string) as `winner`,
  cast(`series_score` as string) as `series_score`,
  cast(`games_in_series` as int64) as `games_in_series`,
  cast(`home_id` as int64) as `home_id`,
  cast(`away_id` as int64) as `away_id`,
  cast(`winner_id` as int64) as `winner_id`

from {{ source('nba_odds_raw', 'nba_betting_series_odds') }}
