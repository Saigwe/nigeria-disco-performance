-- Checks on the regulator's own tables, so readers know which printed figures to trust. Tolerances follow the printed
-- precision: naira to 0.01 bn (each figure +/- 0.005), energy to whole GWh (+/- 0.5), so rounding never raises a flag.
--   1. the "All DisCos" row against the sum of the eleven DisCos, per month and measure
--   2. the quarterly percentage NERC printed against the one recomputed from its own monthly figures
--   3. the same month printed in two reports with different values (revisions)
--   4. naira billed in the revenue table against naira billed in the energy table
with months as (
    select month, measure,
           max(case when disco = 'All DisCos' then value end)                   as printed_total,
           sum(case when disco <> 'All DisCos' then value end)                  as sum_of_discos,
           case when measure like '%gwh' then 0.5 else 0.005 end                as half_unit
    from {{ ref('int_monthly_latest') }}
    group by month, measure
),

quarters as (
    select *,
           -- largest error the printed rounding can cause in a recomputed ratio, in percentage points
           case when billing_efficiency_basis = 'energy (GWh)'
                then 100 * (billing_efficiency_pct / 100) * (1.5 / energy_billed_gwh + 1.5 / energy_offtake_gwh)
                else 100 * (billing_efficiency_pct / 100) * (0.015 / energy_billed_ngn_bn + 0.015 / energy_received_ngn_bn)
           end + 0.005                                                           as be_rounding_pp,
           100 * (collection_efficiency_pct / 100) * (0.015 / collected_ngn_bn + 0.015 / billed_ngn_bn) + 0.005 as ce_rounding_pp
    from {{ ref('rpt_disco_quarter') }}
    where months = 3
)

select 'All DisCos row differs from the sum of DisCos' as check_name, measure as detail,
       strftime(month, '%Y-%m') as period, 'All DisCos' as disco,
       printed_total as printed, round(sum_of_discos, 2) as recomputed,
       round(printed_total - sum_of_discos, 2) as difference
from months
where abs(printed_total - sum_of_discos) > 12 * half_unit
union all
select 'printed quarterly collection efficiency differs from its monthly figures', 'collection efficiency (%)', quarter,
       disco, published_collection_efficiency_pct, collection_efficiency_pct,
       round(published_collection_efficiency_pct - collection_efficiency_pct, 2)
from quarters
where abs(published_collection_efficiency_pct - collection_efficiency_pct) > ce_rounding_pp + 0.01
union all
select 'printed quarterly billing efficiency differs from its monthly figures',
       'billing efficiency (%), ' || billing_efficiency_basis, quarter, disco,
       published_billing_efficiency_pct, billing_efficiency_pct,
       round(published_billing_efficiency_pct - billing_efficiency_pct, 2)
from quarters
where abs(published_billing_efficiency_pct - billing_efficiency_pct) > be_rounding_pp + 0.01
union all
select 'month revised between reports', measure, strftime(month, '%Y-%m'), disco, null, null, revision_spread
from {{ ref('int_monthly_latest') }}
where revision_spread > 0
union all
select 'naira billed differs between revenue and energy tables', 'billed_ngn_bn', strftime(month, '%Y-%m'), disco,
       billed_ngn_bn, energy_billed_ngn_bn, round(billed_ngn_bn - energy_billed_ngn_bn, 2)
from {{ ref('fct_disco_month') }}
where energy_billed_ngn_bn is not null and abs(billed_ngn_bn - energy_billed_ngn_bn) > 0.01
