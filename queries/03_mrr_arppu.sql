-- Выручка за месяц, число платящих, ARPPU и прирост выручки к прошлому месяцу.
-- Техника: оконная функция lag() для сравнения с предыдущей строкой.
with monthly as (
    select date_trunc('month', p.paid_on)::date as month,
           sum(p.amount) as revenue,
           count(distinct s.user_id) as payers
    from kino.payments p
    join kino.subscriptions s on s.id = p.subscription_id
    group by 1
)
select to_char(month, 'YYYY-MM') as month,
       revenue,
       payers,
       round(revenue / payers, 2) as arppu,
       round(100.0 * (revenue - lag(revenue) over w) / lag(revenue) over w, 1) as growth_pct
from monthly
window w as (order by month)
order by month;
