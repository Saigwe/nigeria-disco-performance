-- One value per DisCo, month and measure. Each month is printed in two consecutive reports; the later report wins
-- (it can carry revisions), and the earlier value is kept to measure revisions.
with ranked as (
    select
        *,
        row_number() over (partition by disco, month, measure order by report_quarter desc)  as rn,
        count(*) over (partition by disco, month, measure)                                   as times_published,
        min(value) over (partition by disco, month, measure)                                 as min_value,
        max(value) over (partition by disco, month, measure)                                 as max_value
    from {{ source('bronze', 'nerc_monthly_values') }}
)

select
    disco,
    cast(month as date)                                             as month,
    measure,
    value,
    report_quarter                                                  as latest_report,
    times_published,
    round(max_value - min_value, 2)                                 as revision_spread
from ranked
where rn = 1
