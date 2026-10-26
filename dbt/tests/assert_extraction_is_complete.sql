-- Extraction completeness: every report, table, month and measure has all eleven DisCos plus the total row.
select report_quarter, "table", month, measure, count(distinct disco) as rows_found
from {{ source('bronze', 'nerc_monthly_values') }}
group by all
having count(distinct disco) <> 12
