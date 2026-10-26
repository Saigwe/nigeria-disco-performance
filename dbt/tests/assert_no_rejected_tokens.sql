-- No token was rejected: every non-numeric token was repaired by an explicit, logged rule.
select * from {{ source('bronze', 'nerc_extraction_issues') }} where repaired_to is null
