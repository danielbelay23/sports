select
  *
from {{ source('nba_raw', 'games') }}
