-- One row per DisCo and month, Apr 2024 onwards, with the regulator's efficiency measures recomputed from the money:
--   collection efficiency (CE) = collected / billed
--   billing efficiency (BE)    = billed / value of energy received (naira, from Apr 2025), or
--                                billed GWh / offtake GWh (energy, to Mar 2025): NERC changed the basis in 2025/Q2
--   ATC&C loss                 = 1 - BE x CE
select
    disco,
    month,
    'Q' || quarter(month)                                                       as quarter_label,
    year(month) || '/Q' || quarter(month)                                       as quarter,
    max(case when measure = 'billed_ngn_bn' then value end)                     as billed_ngn_bn,
    max(case when measure = 'collected_ngn_bn' then value end)                  as collected_ngn_bn,
    max(case when measure = 'energy_received_ngn_bn' then value end)            as energy_received_ngn_bn,
    max(case when measure = 'energy_billed_ngn_bn' then value end)              as energy_billed_ngn_bn,
    max(case when measure = 'energy_offtake_gwh' then value end)                as energy_offtake_gwh,
    max(case when measure = 'energy_billed_gwh' then value end)                 as energy_billed_gwh,
    collected_ngn_bn / nullif(billed_ngn_bn, 0)                                 as collection_efficiency,
    coalesce(energy_billed_ngn_bn / nullif(energy_received_ngn_bn, 0),
             energy_billed_gwh / nullif(energy_offtake_gwh, 0))                 as billing_efficiency,
    case when energy_received_ngn_bn is not null then 'naira' else 'energy (GWh)' end as billing_efficiency_basis,
    1 - billing_efficiency * collection_efficiency                              as atcc_loss,
    max(revision_spread)                                                        as max_revision_spread
from {{ ref('int_monthly_latest') }}
group by disco, month
