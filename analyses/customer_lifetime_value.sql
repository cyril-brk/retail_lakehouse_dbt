-- ANALYSIS — lives in analyses/. dbt COMPILES these (so ref()/macros work) but
-- does NOT run or materialize them. Use `dbt compile` then copy the compiled SQL
-- from target/compiled/... into a BI tool or ad-hoc query.
--
-- Example: top 20 customers by lifetime value with their region.
select
    customer_id,
    first_name,
    last_name,
    region,
    lifetime_orders,
    lifetime_value
from {{ ref('dim_customers') }}
where has_ordered
order by lifetime_value desc
limit 20
