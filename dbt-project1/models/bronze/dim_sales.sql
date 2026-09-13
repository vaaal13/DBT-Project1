select *
from {{ source('source', 'fact_sales') }}