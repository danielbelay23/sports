select
  *
from {{ source('nba_odds_raw', 'nba_teams_all') }}
