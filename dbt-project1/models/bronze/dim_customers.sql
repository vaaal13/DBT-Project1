select *
from {{ source('source', 'dim_customers') }}