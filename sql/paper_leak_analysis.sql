-- =====================================================
-- INDIA PAPER LEAK ANALYSIS
-- SQL ANALYSIS
-- =====================================================


-- 1. Total number of reported incidents

SELECT
    COUNT(*) AS total_records
FROM dbo.paper_leaks_cleaned;


-- 2. Number of incidents by exam category

SELECT
    exam_category,
    COUNT(*) AS incident_count
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY incident_count DESC;


-- 3. Total arrests by exam category

SELECT
    exam_category,
    SUM(arrests_numeric) AS total_arrests
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY total_arrests DESC;


-- 4. Total convictions by exam category

SELECT
    exam_category,
    SUM(convictions_numeric) AS total_convictions
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY total_convictions DESC;


-- 5. Compare incidents, arrests and convictions

SELECT
    exam_category,
    COUNT(*) AS incident_count,
    SUM(arrests_numeric) AS total_arrests,
    COALESCE(SUM(convictions_numeric), 0) AS total_convictions
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY total_arrests DESC;


-- 6. Exam categories with above-average incident counts

WITH category_counts AS (
    SELECT
        exam_category,
        COUNT(*) AS incident_count
    FROM dbo.paper_leaks_cleaned
    GROUP BY exam_category
)

SELECT
    exam_category,
    incident_count
FROM category_counts
WHERE incident_count > (
    SELECT AVG(incident_count)
    FROM category_counts
)
ORDER BY incident_count DESC;


-- 7. Rank exam categories by reported incidents

SELECT
    exam_category,
    COUNT(*) AS incident_count,
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS category_rank
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY category_rank;


---- 8. Rank exam categories within each year

SELECT 
    year,
    exam_category,
    COUNT(*) AS incident_count,
    RANK() OVER (
        PARTITION BY year
        ORDER BY COUNT(*) DESC
    ) AS category_rank
FROM dbo.paper_leaks_cleaned
GROUP BY year, exam_category
ORDER BY year, category_rank;


---- 9. What was the #1 exam category each year?

with yearly_category_counts as(
    select year,
    exam_category,
    count(*) as incident_count,
    rank() over(partition by year order by count(*) desc) as category_rank
    from dbo.paper_leaks_cleaned
    group by year,exam_category
)
select year,exam_category,incident_count
from yearly_category_counts
where category_rank=1
order by year


-- 10. Which incidents had the highest number of arrests?

select top 10
year,
incident_id,exam_name,
area_clean,
exam_category,
arrests_numeric
from dbo.paper_leaks_cleaned
where arrests_numeric is not null
order by arrests_numeric desc


-- 11. Which regions had the highest total arrests?

select 
area_clean,
sum(arrests_numeric) as total_arrests,
count(*) as incident_count
from dbo.paper_leaks_cleaned
where arrests_numeric is not NULL
group by area_clean
order by total_arrests desc


-- 12. Which regions had the highest average arrests per incident?

select
area_clean,
avg(arrests_numeric) as avg_arrests,
count(*) as incident_count
from dbo.paper_leaks_cleaned
where arrests_numeric is not NULL
group by area_clean
order by avg_arrests desc


-- 13. Which exam categories have the highest average arrests?

SELECT
    exam_category,
    AVG(arrests_numeric) AS avg_arrests,
    COUNT(*) AS incidents_with_arrest_data
FROM dbo.paper_leaks_cleaned
WHERE arrests_numeric IS NOT NULL
GROUP BY exam_category
ORDER BY avg_arrests DESC;


-- 14. Which exam categories had the highest recorded convictions?

SELECT
    exam_category,
    COALESCE(SUM(convictions_numeric), 0) AS total_convictions,
    COUNT(convictions_numeric) AS incidents_with_conviction_data
FROM dbo.paper_leaks_cleaned
GROUP BY exam_category
ORDER BY total_convictions DESC;


-- 15. Compare arrests and convictions by exam category

select
exam_category,
count(*) as incident_count,
coalesce(sum(arrests_numeric),0) as total_arrests,
coalesce(sum(convictions_numeric),0)as total_convictions,
count(convictions_numeric) as incidents_with_conviction_data
from dbo.paper_leaks_cleaned
group by exam_category
order by total_arrests desc


-- 16. Which incidents had the highest number of affected aspirants?

select
top 10
incident_id,
year,
exam_name,
area_clean,
exam_category,
aspirants_affected_numeric
from dbo.paper_leaks_cleaned
where aspirants_affected_numeric is not null
order by aspirants_affected_numeric desc


-- 17. Which exam categories had the most reported affected aspirants?

select
exam_category,
sum(aspirants_affected_numeric) as total_aspirants_affected,
count(aspirants_affected_numeric) as incidents_with_impact_data
from dbo.paper_leaks_cleaned
group by exam_category
order by total_aspirants_affected desc


-- 18. How many incidents involved each response action?

select
SUM(CAST(exam_cancelled AS INT)) AS cancelled_incidents,
SUM(CAST(retest AS INT)) AS retest_incidents,
SUM(CAST(probe AS INT)) AS probe_incidents,
SUM(CAST(arrests_fir AS INT)) AS arrests_fir_incidents
from dbo.paper_leaks_cleaned


-- 19. Check missing values in key analytical columns

select
count(*) as incident_count,
sum(
    case 
    when arrests_numeric is null then 1
    else 0
    end
) as missing_arrests,
sum(
    case
    when convictions_numeric is null then 1
    else 0
    end
) as missing_convictions,
sum(
    case
    when aspirants_affected_numeric is null then 1
    else 0
    end
) as missing_impact_data,
sum(
    case
    when area_clean is null then 1
    else 0
    end
) as missing_region
from dbo.paper_leaks_cleaned


-- 20. Calculate data completeness percentages
select
count(*) as total_icidents,
cast(
    100.0 *count(arrests_numeric)/count(*) as decimal(5,2)
) as arrest_data_pct,
cast(
    100.0 *count(convictions_numeric)/count(*) as decimal(5,2)
) as convictions_data_pct,
cast(
    100.0 *count(aspirants_affected_numeric)/count(*) as decimal(5,2)
) as impact_data_pct
from dbo.paper_leaks_cleaned


-- 21. Annual trend of recorded incidents

select
year,
count(*) as incident_count
from dbo.paper_leaks_cleaned
group by year
order by year


-- 22. Which conducting bodies had the most recorded incidents?
select
conducting_body,
count(*) as incident_count
from dbo.paper_leaks_cleaned
group by conducting_body
order by incident_count desc


-- 23. Inspect conducting body names for possible duplicates

select distinct
conducting_body
from dbo.paper_leaks_cleaned
WHERE conducting_body LIKE '%CBSE%'
   OR conducting_body LIKE '%Vyapam%'
   OR conducting_body LIKE '%National Testing Agency%'
   OR conducting_body LIKE '%NTA%'
ORDER BY conducting_body


-- 24. Standardize conducting body names for analysis

GO

CREATE VIEW dbo.vw_paper_leaks_analysis AS
SELECT
    *,
    CASE
        WHEN conducting_body IN (
            'CBSE',
            'Central Board of Secondary Education (CBSE)'
        )
        THEN 'CBSE'
        ELSE conducting_body
    END AS conducting_body_standardized
FROM dbo.paper_leaks_cleaned;
GO


SELECT TOP 10
    conducting_body,
    conducting_body_standardized
FROM dbo.vw_paper_leaks_analysis;


-- 25. Verify standardized conducting body counts

select 
conducting_body_standardized,
count(*) as incident_count
from dbo.vw_paper_leaks_analysis
where conducting_body_standardized='CBSE'
group by conducting_body_standardized