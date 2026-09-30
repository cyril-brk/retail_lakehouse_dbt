-- SINGULAR TEST — a hand-written test that is just a SELECT. dbt considers the
-- test PASSED when the query returns ZERO rows. Here: no order should have a
-- negative total. (Generic tests live in the _*.yml files; singular tests live
-- as standalone .sql files in tests/.)
select
    order_id,
    order_amount
from {{ ref('fct_orders') }}
where order_amount < 0
