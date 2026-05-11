select
  *
from {{ source('nba_odds_raw', 'nba_betting_spread') }}
