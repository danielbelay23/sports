select
  *
from {{ source('nba_raw', 'players') }}
