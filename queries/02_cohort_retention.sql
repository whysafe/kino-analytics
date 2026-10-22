-- Когортное удержание: из зарегистрировавшихся в месяце X какая доля смотрела через 0, 1, 2… месяцев.
-- Техника: когорта по месяцу регистрации, номер месяца через age(), сводная таблица через FILTER.
with activity as (
    select distinct u.id,
           date_trunc('month', u.signed_up)::date as cohort,
           (extract(year from age(date_trunc('month', v.started_at), date_trunc('month', u.signed_up))) * 12
            + extract(month from age(date_trunc('month', v.started_at), date_trunc('month', u.signed_up))))::int as month_n
    from kino.users u
    join kino.views v on v.user_id = u.id
),
sizes as (
    select date_trunc('month', signed_up)::date as cohort, count(*) as users
    from kino.users
    group by 1
)
select to_char(s.cohort, 'YYYY-MM') as cohort,
       s.users,
       round(100.0 * count(*) filter (where a.month_n = 0) / s.users, 1) as m0,
       round(100.0 * count(*) filter (where a.month_n = 1) / s.users, 1) as m1,
       round(100.0 * count(*) filter (where a.month_n = 2) / s.users, 1) as m2,
       round(100.0 * count(*) filter (where a.month_n = 3) / s.users, 1) as m3,
       round(100.0 * count(*) filter (where a.month_n = 6) / s.users, 1) as m6
from sizes s
left join activity a on a.cohort = s.cohort
group by s.cohort, s.users
order by s.cohort;
