-- One row per DisCo and quarter: efficiencies recomputed from the monthly money, beside the percentages NERC printed,
-- plus the naira lost to billing and to collection, and the MYTO target where the report gives one.
with q as (
    select
        disco,
        quarter,
        count(*)                                                                as months,
        sum(billed_ngn_bn)                                                      as billed_ngn_bn,
        sum(collected_ngn_bn)                                                   as collected_ngn_bn,
        sum(energy_received_ngn_bn)                                             as energy_received_ngn_bn,
        sum(energy_billed_ngn_bn)                                               as energy_billed_ngn_bn,
        sum(energy_offtake_gwh)                                                 as energy_offtake_gwh,
        sum(energy_billed_gwh)                                                  as energy_billed_gwh,
        any_value(billing_efficiency_basis)                                     as billing_efficiency_basis
    from {{ ref('fct_disco_month') }}
    group by disco, quarter
),

published as (
    select disco, quarter, measure, arg_max(published_pct, report_quarter) as published_pct
    from {{ source('bronze', 'nerc_quarterly_published') }}
    group by disco, quarter, measure
),

atcc as (
    select disco, atcc_quarter as quarter, arg_max(atcc_pct, report_quarter) as published_atcc_pct,
           arg_max(myto_target_pct, report_quarter) as myto_target_pct
    from {{ source('bronze', 'nerc_atcc_published') }}
    group by disco, atcc_quarter
)

select
    q.*,
    round(100 * collected_ngn_bn / nullif(billed_ngn_bn, 0), 2)                                 as collection_efficiency_pct,
    round(100 * coalesce(energy_billed_ngn_bn / nullif(energy_received_ngn_bn, 0),
                         energy_billed_gwh / nullif(energy_offtake_gwh, 0)), 2)                 as billing_efficiency_pct,
    round(100 * (1 - coalesce(energy_billed_ngn_bn / nullif(energy_received_ngn_bn, 0),
                              energy_billed_gwh / nullif(energy_offtake_gwh, 0))
                   * collected_ngn_bn / nullif(billed_ngn_bn, 0)), 2)                           as atcc_loss_pct,
    pc.published_pct                                                                            as published_collection_efficiency_pct,
    coalesce(pn.published_pct, pg.published_pct)                                                as published_billing_efficiency_pct,
    a.published_atcc_pct,
    a.myto_target_pct,
    round(energy_received_ngn_bn - energy_billed_ngn_bn, 2)                                     as billing_loss_ngn_bn,
    round(billed_ngn_bn - collected_ngn_bn, 2)                                                  as collection_loss_ngn_bn,
    round(energy_received_ngn_bn - collected_ngn_bn, 2)                                         as total_value_lost_ngn_bn
from q
left join published pc on pc.disco = q.disco and pc.quarter = q.quarter and pc.measure = 'collection_efficiency'
left join published pn on pn.disco = q.disco and pn.quarter = q.quarter and pn.measure = 'billing_efficiency_ngn'
left join published pg on pg.disco = q.disco and pg.quarter = q.quarter and pg.measure = 'billing_efficiency_gwh'
left join atcc a on a.disco = q.disco and a.quarter = q.quarter
