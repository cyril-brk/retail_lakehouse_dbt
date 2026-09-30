with source as (
    select * from {{ source('retail_raw', 'raw_payments') }}
)

select
    payment_id,
    order_id,
    lower(trim(payment_method))   as payment_method,
    -- demonstrate a reusable MACRO: convert a decimal amount to cents (bigint)
    {{ dollars_to_cents('amount') }} as amount_cents,
    cast(amount as decimal(12,2)) as amount,
    cast(paid_at as timestamp)    as paid_at
from source
