with source as (
    select * from {{ source('retail_raw', 'raw_products') }}
)

select
    product_id,
    upper(trim(sku))            as sku,
    initcap(trim(product_name)) as product_name,
    trim(category)              as category,
    cast(price as decimal(10,2)) as price,
    cast(updated_at as timestamp) as updated_at
from source
