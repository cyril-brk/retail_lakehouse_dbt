-- MART / FACT: one row per payment, with order + customer context.
with payments as (
    select * from {{ ref('stg_payments') }}
),

orders as (
    select order_id, customer_id, store_id from {{ ref('stg_orders') }}
)

select
    p.payment_id,
    p.order_id,
    o.customer_id,
    o.store_id,
    p.payment_method,
    p.amount,
    p.amount_cents,
    p.paid_at,
    cast(p.paid_at as date) as paid_date
from payments p
left join orders o on p.order_id = o.order_id
