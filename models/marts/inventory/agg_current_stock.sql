-- MART (aggregate table): current stock level per store+product, summing all
-- signed quantity changes. Built on top of the incremental events fact so it
-- always reflects the latest loaded events.
with events as (
    select * from {{ ref('fct_inventory_events') }}
)

select
    store_id,
    product_id,
    sum(quantity_change)  as stock_on_hand,
    max(event_at)         as last_event_at,
    count(*)              as n_events
from events
group by store_id, product_id
