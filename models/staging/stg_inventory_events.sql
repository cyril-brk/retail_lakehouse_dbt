with source as (
    select * from {{ source('retail_raw', 'raw_inventory_events') }}
)

select
    event_id,
    store_id,
    product_id,
    lower(trim(event_type))    as event_type,
    cast(quantity_change as int) as quantity_change,
    cast(event_at as timestamp) as event_at
from source
