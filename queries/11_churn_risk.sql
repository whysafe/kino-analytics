-- Кого пора возвращать: платная подписка активна, но последние 14 дней года ничего не смотрел.
-- Техника: NOT EXISTS по индексу (user_id, started_at) и частичный индекс активных подписок.
select u.id, u.email, p.name as plan,
       max(v.started_at)::date as last_view,
       date '2025-12-31' - max(v.started_at)::date as days_silent,
       count(v.id) as total_views
from kino.subscriptions s
join kino.users u on u.id = s.user_id
join kino.plans p on p.id = s.plan_id
left join kino.views v on v.user_id = u.id
where s.ended_on is null
  and s.plan_id > 0
  and not exists (
      select 1 from kino.views r
      where r.user_id = u.id and r.started_at >= timestamptz '2025-12-18'
  )
group by u.id, u.email, p.name, p.monthly_price
order by p.monthly_price desc, days_silent desc nulls first, u.id
limit 20;
