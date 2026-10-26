-- Naira billed must agree between the revenue table and the energy table of the same report family.
select * from {{ ref('rpt_publisher_checks') }} where check_name = 'naira billed differs between revenue and energy tables'
