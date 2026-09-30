-- STAGING model: 1:1 with the source, light cleaning only (rename, cast, trim).
-- Materialized as a VIEW (set in dbt_project.yml). No business logic here.
with source as (
    select * from {{ source('retail_raw', 'raw_customers') }}
),

cleaned as (
    select
        customer_id,
        -- trim + title-case the deliberately-dirty name fields
        initcap(trim(first_name))                as first_name,
        initcap(trim(last_name))                 as last_name,
        nullif(lower(trim(email)), '')           as email,
        upper(trim(country_code))                as country_code,
        cast(signup_at as timestamp)             as signed_up_at
    from source
)

select * from cleaned
