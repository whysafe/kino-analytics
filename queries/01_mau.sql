-- MAU и средний DAU по месяцам: сколько разных людей смотрело хоть что-то за месяц и в среднем за день.
-- Техника: две агрегации с разной гранулярностью, соединённые по месяцу.
with daily as (
    select date_trunc('day', started_at)::date as day, count(distinct user_id) as dau
    from kino.views
    group by 1
),
monthly as (
    select date_trunc('month', started_at)::date as month, count(distinct user_id) as mau
    from kino.views
    group by 1
)
select to_char(m.month, 'YYYY-MM') as month,
       m.mau,
       round(avg(d.dau)) as avg_dau,
       round(100.0 * avg(d.dau) / m.mau, 1) as stickiness_pct   -- DAU/MAU: насколько смотреть каждый день вошло в привычку
from monthly m
join daily d on date_trunc('month', d.day) = m.month
where m.month < date '2026-01-01'
group by m.month, m.mau
order by m.month;
