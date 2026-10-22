-- Выручка по неделям с накопительным итогом и скользящим средним за 4 недели.
-- Техника: оконные рамки ROWS BETWEEN для скользящего среднего и накопительной суммы.
with weekly as (
    select date_trunc('week', paid_on)::date as week, sum(amount) as revenue
    from kino.payments
    group by 1
)
select to_char(week, 'YYYY-MM-DD') as week,
       revenue,
       sum(revenue) over (order by week rows between unbounded preceding and current row) as running_total,
       round(avg(revenue) over (order by week rows between 3 preceding and current row), 2) as moving_avg_4w
from weekly
order by week;
