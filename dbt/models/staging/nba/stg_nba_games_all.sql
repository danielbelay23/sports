select
  *
from {{ source('nba_odds_raw', 'nba_games_all') }}
