with source as (
    select * from {{ source('retail_raw', 'raw_orders') }}
)

select
    order_id,
    customer_id,
    store_id,
    cast(ordered_at as timestamp) as ordered_at,
    cast(updated_at as timestamp) as updated_at,
    lower(trim(status))           as status,
    -- boolean flag makes downstream aggregation clearer
    case when lower(trim(status)) = 'returned' then true else false end as is_returned
from source
