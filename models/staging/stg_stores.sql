with source as (
    select * from {{ source('retail_raw', 'raw_stores') }}
)

select
    store_id,
    trim(store_name)          as store_name,
    upper(trim(country_code)) as country_code,
    trim(store_type)          as store_type
from source
