{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='sale_id',
    file_format='delta',
    database='dbt_source_1',
    schema='silver_layer'
) }}

with sales as (
    select
        upper(trim(sale_id)) as sale_id,
        upper(trim(order_id)) as order_id,
        cast(order_line_number as int) as order_line_number,
        cast(sale_date as date) as sale_date,
        upper(trim(customer_id)) as customer_id,
        upper(trim(product_id)) as product_id,
        upper(trim(location_id)) as location_id,
        cast(quantity as int) as quantity,
        cast(unit_price as decimal(12, 2)) as unit_price,
        cast(unit_cost as decimal(12, 2)) as unit_cost,
        cast(discount_amount as decimal(12, 2)) as discount_amount,
        upper(trim(currency_code)) as currency_code,
        trim(sales_channel) as sales_channel,
        trim(payment_method) as payment_method
    from {{ ref('dim_sales') }}
),

joined as (
    select
        s.*,

        nullif(trim(c.first_name), '') as customer_first_name,
        nullif(trim(c.last_name), '') as customer_last_name,
        lower(nullif(trim(c.email), '')) as customer_email,
        nullif(trim(c.customer_segment), '') as customer_segment,
        cast(c.signup_date as date) as customer_signup_date,

        upper(trim(p.sku)) as product_sku,
        nullif(trim(p.product_name), '') as product_name,
        nullif(trim(p.category), '') as product_category,
        nullif(trim(p.brand), '') as product_brand,

        nullif(trim(l.location_name), '') as location_name,
        nullif(trim(l.city), '') as city,
        nullif(trim(l.state), '') as state,
        nullif(trim(l.region), '') as region,
        nullif(trim(l.country), '') as country

    from sales s

    left join {{ ref('dim_customers') }} c
        on s.customer_id = upper(trim(c.customer_id))

    left join {{ ref('dim_products') }} p
        on s.product_id = upper(trim(p.product_id))

    left join {{ ref('dim_location') }} l
        on s.location_id = upper(trim(l.location_id))
)

select
    *,
    cast(
        quantity * unit_price
        as decimal(18, 2)
    ) as gross_sales_amount,
    cast(
        quantity * unit_price - discount_amount
        as decimal(18, 2)
    ) as net_sales_amount,
    cast(
        quantity * unit_cost
        as decimal(18, 2)
    ) as cost_of_goods_sold,
    cast(
        quantity * unit_price
        - discount_amount
        - quantity * unit_cost
        as decimal(18, 2)
    ) as gross_profit
from joined