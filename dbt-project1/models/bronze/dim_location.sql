select *
from {{ source('source', 'dim_location') }}