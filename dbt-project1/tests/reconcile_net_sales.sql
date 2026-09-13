with layer_totals as (

    select
        'bronze' as layer,
        upper(trim(currency_code)) as currency_code,
        sum(
            cast(
                cast(quantity as int)
                * cast(unit_price as decimal(12, 2))
                - cast(discount_amount as decimal(12, 2))
                as decimal(18, 2)
            )
        ) as net_sales,
        count(*) - count(quantity * unit_price - discount_amount)
            as missing_amounts
    from {{ ref('dim_sales') }}
    group by upper(trim(currency_code))

    union all

    select
        'silver' as layer,
        currency_code,
        sum(net_sales_amount) as net_sales,
        count(*) - count(net_sales_amount) as missing_amounts
    from {{ ref('flat_schema') }}
    group by currency_code

    union all

    select
        'gold' as layer,
        currency_code,
        sum(net_sales_amount) as net_sales,
        count(*) - count(net_sales_amount) as missing_amounts
    from {{ ref('gold_dataset') }}
    group by currency_code

)

select
    currency_code,
    count(distinct layer) as layers_found,
    min(net_sales) as lowest_total,
    max(net_sales) as highest_total,
    sum(missing_amounts) as missing_amounts
from layer_totals
group by currency_code
having
    count(distinct layer) <> 3
    or min(net_sales) <> max(net_sales)
    or sum(missing_amounts) > 0
    or currency_code is null