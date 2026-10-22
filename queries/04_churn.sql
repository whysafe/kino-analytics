-- Отток платных подписок по месяцам: доля подписок, активных на начало месяца, которые закончились в нём.
-- Техника: generate_series для календаря и условная агрегация по пересечению периодов.
with months as (
    select generate_series(date '2025-02-01', date '2025-12-01', interval '1 month')::date as month
)
select to_char(m.month, 'YYYY-MM') as month,
       count(*) filter (where s.started_on < m.month) as active_at_start,
       count(*) filter (where s.started_on < m.month and s.ended_on < (m.month + interval '1 month')::date) as churned,
       round(100.0 * count(*) filter (where s.started_on < m.month and s.ended_on < (m.month + interval '1 month')::date)
             / nullif(count(*) filter (where s.started_on < m.month), 0), 1) as churn_pct
from months m
join kino.subscriptions s
  on s.plan_id > 0
 and s.started_on < (m.month + interval '1 month')::date
 and (s.ended_on is null or s.ended_on >= m.month)
group by m.month
order by m.month;
