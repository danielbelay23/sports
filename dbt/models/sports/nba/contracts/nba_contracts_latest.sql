select *
from {{ ref('stg_nba_contracts') }}
where snapshot_date = (
    select max(snapshot_date)
    from {{ ref('stg_nba_contracts') }}
)
