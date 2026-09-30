-- MART / DIMENSION: store dimension enriched with country attributes.
with stores as (
    select * from {{ ref('stg_stores') }}
),

countries as (
    select * from {{ ref('country_codes') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['s.store_id']) }} as store_sk,
    s.store_id,
    s.store_name,
    s.store_type,
    s.country_code,
    c.country_name,
    c.region
from stores s
left join countries c on s.country_code = c.country_code
