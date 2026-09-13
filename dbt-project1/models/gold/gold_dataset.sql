{{ config(
    materialized='table',
    file_format='delta',
    database='dbt_source_1',
    schema='gold_layer'
) }}

with daily_sales as (
    select
        sale_date,
        location_id,
        location_name,
        city,
        state,
        region,
        country,
        sales_channel,
        currency_code,

        count(*) as sales_line_count,
        count(distinct order_id) as order_count,
        count(distinct customer_id) as customer_count,

        sum(quantity) as units_sold,
        sum(gross_sales_amount) as gross_sales_amount,
        sum(discount_amount) as discount_amount,
        sum(net_sales_amount) as net_sales_amount,
        sum(cost_of_goods_sold) as cost_of_goods_sold,
        sum(gross_profit) as gross_profit

    from {{ ref('flat_schema') }}

    group by
        sale_date,
        location_id,
        location_name,
        city,
        state,
        region,
        country,
        sales_channel,
        currency_code
)

select
    *,
    cast(
        net_sales_amount / nullif(order_count, 0)
        as decimal(18, 2)
    ) as average_order_value,

    cast(
        100.0 * gross_profit / nullif(net_sales_amount, 0)
        as decimal(10, 2)
    ) as gross_margin_pct

from daily_sales