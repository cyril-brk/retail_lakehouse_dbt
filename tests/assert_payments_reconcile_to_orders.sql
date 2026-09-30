-- SINGULAR TEST: flag orders where total payments differ from the order amount
-- by more than a cent (rounding tolerance). Returns offending rows -> failure.
-- Great example of a business-rule / reconciliation test.
with orders as (
    select order_id, order_amount, amount_paid
    from {{ ref('fct_orders') }}
    where status = 'completed'
)

select
    order_id,
    order_amount,
    amount_paid,
    abs(order_amount - amount_paid) as diff
from orders
where abs(order_amount - amount_paid) > 0.01
