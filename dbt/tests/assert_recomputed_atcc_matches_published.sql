-- My ATC&C, recomputed from NERC's monthly naira figures, must match the ATC&C NERC published within 0.15pp
-- for every DisCo and quarter where both exist (rounding of the printed inputs explains differences up to that).
select disco, quarter, atcc_loss_pct, published_atcc_pct
from {{ ref('rpt_disco_quarter') }}
where published_atcc_pct is not null and months = 3 and abs(atcc_loss_pct - published_atcc_pct) > 0.15
