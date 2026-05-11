select
  *
from {{ source('nba_raw', 'team_statistics') }}
