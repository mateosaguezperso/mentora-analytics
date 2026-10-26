-- Grain: one row per mentor, enriched with company attributes.

with mentors as (

    select * from {{ ref('stg_platform__mentors') }}

),

companies as (

    select
        company_id,
        company_name,
        industry
    from {{ ref('stg_platform__companies') }}

)

select
    mentors.mentor_id,
    mentors.company_id,
    companies.company_name,
    companies.industry,
    mentors.job_title,
    mentors.job_family,
    mentors.is_active,
    mentors.joined_at

from mentors
left join companies
    on mentors.company_id = companies.company_id
