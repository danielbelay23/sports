{{
    config(
        materialized='view'
    )
}}

select *

from {{ ref('stg_nba_kaggle_team_histories') }}
