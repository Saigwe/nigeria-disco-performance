-- The DisCo scorecard for the latest quarter: ATC&C loss against the MYTO target, its two halves (billing and
-- collection), the naira lost, the change on the previous quarter, and the rank.
with q as (
    select * from {{ ref('rpt_disco_quarter') }} where disco <> 'All DisCos' and months = 3
),

latest as (select max(quarter) as quarter from q where energy_received_ngn_bn is not null),

ranked as (
    select
        q.*,
        lag(atcc_loss_pct) over (partition by disco order by quarter)                     as prev_atcc_loss_pct,
        sum(total_value_lost_ngn_bn) over (partition by disco order by quarter
                                           rows between 3 preceding and current row)        as value_lost_last_4q_ngn_bn
    from q
)

select
    r.disco,
    r.quarter,
    r.atcc_loss_pct,
    r.myto_target_pct,
    round(r.atcc_loss_pct - r.myto_target_pct, 2)                                           as gap_to_target_pp,
    r.atcc_loss_pct <= r.myto_target_pct                                                    as meets_target,
    r.billing_efficiency_pct,
    r.collection_efficiency_pct,
    round(r.atcc_loss_pct - r.prev_atcc_loss_pct, 2)                                        as change_vs_prev_quarter_pp,
    r.energy_received_ngn_bn,
    r.billing_loss_ngn_bn,
    r.collection_loss_ngn_bn,
    r.total_value_lost_ngn_bn,
    case when r.billing_loss_ngn_bn >= r.collection_loss_ngn_bn then 'billing (metering, theft, enumeration)'
         else 'collection (unpaid bills)' end                                               as bigger_problem,
    rank() over (order by r.atcc_loss_pct)                                                  as rank_best_to_worst
from ranked r
join latest l using (quarter)
