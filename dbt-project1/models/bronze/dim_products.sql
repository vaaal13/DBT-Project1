select *
from {{ source('source', 'dim_products') }}