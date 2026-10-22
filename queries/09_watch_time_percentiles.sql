-- Сколько часов в месяц смотрит пользователь: перцентили по тарифам.
-- Техника: percentile_cont внутри группы; тариф берётся по подписке, активной в середине месяца.
with user_month as (
    select v.user_id, date_trunc('month', v.started_at)::date as month, sum(v.watched_min) / 60.0 as hours
    from kino.views v
    where v.started_at < timestamptz '2026-01-01'
    group by 1, 2
),
with_plan as (
    select um.*, coalesce(p.name, 'Без подписки') as plan
    from user_month um
    left join kino.subscriptions s
      on s.user_id = um.user_id
     and s.started_on <= um.month + 14
     and (s.ended_on is null or s.ended_on >= um.month + 14)
    left join kino.plans p on p.id = s.plan_id
)
select plan,
       count(*) as user_months,
       round(percentile_cont(0.25) within group (order by hours)::numeric, 1) as p25_hours,
       round(percentile_cont(0.5) within group (order by hours)::numeric, 1) as median_hours,
       round(percentile_cont(0.9) within group (order by hours)::numeric, 1) as p90_hours
from with_plan
group by plan
order by median_hours desc;
