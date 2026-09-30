-- MART / DIMENSION: product dimension with category target joined from a seed.
with products as (
    select * from {{ ref('stg_products') }}
),

targets as (
    select * from {{ ref('category_targets') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['p.product_id']) }} as product_sk,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.price,
    t.monthly_revenue_target as category_monthly_target,
    -- simple price banding for analysis
    case
        when p.price < 15  then 'budget'
        when p.price < 50  then 'mid'
        else 'premium'
    end as price_band
from products p
left join targets t on p.category = t.category
