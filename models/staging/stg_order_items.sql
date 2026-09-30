with source as (
    select * from {{ source('retail_raw', 'raw_order_items') }}
)

select
    order_item_id,
    order_id,
    product_id,
    cast(quantity as int)            as quantity,
    cast(unit_price as decimal(10,2)) as unit_price,
    cast(line_total as decimal(12,2)) as line_total
from source
