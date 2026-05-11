select
  *
from {{ source('nba_odds_raw', 'nba_players_game_stats') }}
