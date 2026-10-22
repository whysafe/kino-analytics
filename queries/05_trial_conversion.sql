-- Конверсия пробной недели в платную подписку по устройству и выбранные тарифы.
-- Техника: LATERAL с LIMIT 1 берёт первую платную подписку, разбивка по тарифам через FILTER.
select u.device,
       count(*) as trials,
       count(*) filter (where paid.plan_id is not null) as converted,
       round(100.0 * count(*) filter (where paid.plan_id is not null) / count(*), 1) as conversion_pct,
       count(*) filter (where paid.plan_id = 1) as basic,
       count(*) filter (where paid.plan_id = 2) as standard,
       count(*) filter (where paid.plan_id = 3) as premium
from kino.users u
left join lateral (
    select s.plan_id
    from kino.subscriptions s
    where s.user_id = u.id and s.plan_id > 0
    order by s.started_on
    limit 1
) paid on true
where u.signed_up <= date '2025-12-24'   -- у поздних регистраций пробная неделя ещё не закончилась
group by u.device
order by conversion_pct desc;
