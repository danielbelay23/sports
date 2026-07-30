with source as (
    select *
    from {{ source('nba_contracts', 'contract_snapshots') }}
)

select
    snapshot_date,
    scraped_at,
    source_url,
    source_rank,
    team_code,
    player_id,
    player_name,
    season_index,
    season_label,
    safe_cast(split(season_label, '-')[safe_offset(0)] as int64) as season_start_year,
    safe_cast(
        concat(
            substr(split(season_label, '-')[safe_offset(0)], 1, 2),
            split(season_label, '-')[safe_offset(1)]
        ) as int64
    ) as season_end_year,
    salary_raw,
    safe_cast(regexp_replace(salary_raw, r'[^0-9.-]', '') as numeric) as salary_amount,
    guaranteed_raw,
    safe_cast(regexp_replace(guaranteed_raw, r'[^0-9.-]', '') as numeric)
        as guaranteed_amount,
    is_player_option,
    is_team_option,
    is_partially_guaranteed
from source
