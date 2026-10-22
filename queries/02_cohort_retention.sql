-- Когортное удержание: из зарегистрировавшихся в месяце X какая доля смотрела через 0, 1, 2… месяцев.
-- Техника: когорта по месяцу регистрации, номер месяца через age(), сводная таблица через FILTER.
-- Месяцы, которые для когорты ещё не наступили, остаются пустыми, а не нулями.
with activity as (
    select distinct u.id,
           date_trunc('month', u.signed_up)::date as cohort,
           (extract(year from age(date_trunc('month', v.started_at), date_trunc('month', u.signed_up))) * 12
            + extract(month from age(date_trunc('month', v.started_at), date_trunc('month', u.signed_up))))::int as month_n
    from kino.users u
    join kino.views v on v.user_id = u.id
    where v.started_at < timestamptz '2026-01-01'
),
sizes as (
    select date_trunc('month', signed_up)::date as cohort, count(*) as users
    from kino.users
    group by 1
)
select to_char(s.cohort, 'YYYY-MM') as cohort,
       s.users,
       case when s.cohort + interval '0 month' < date '2026-01-01'
            then round(100.0 * count(*) filter (where a.month_n = 0) / s.users, 1) end as m0,
       case when s.cohort + interval '1 month' < date '2026-01-01'
            then round(100.0 * count(*) filter (where a.month_n = 1) / s.users, 1) end as m1,
       case when s.cohort + interval '2 month' < date '2026-01-01'
            then round(100.0 * count(*) filter (where a.month_n = 2) / s.users, 1) end as m2,
       case when s.cohort + interval '3 month' < date '2026-01-01'
            then round(100.0 * count(*) filter (where a.month_n = 3) / s.users, 1) end as m3,
       case when s.cohort + interval '6 month' < date '2026-01-01'
            then round(100.0 * count(*) filter (where a.month_n = 6) / s.users, 1) end as m6
from sizes s
left join activity a on a.cohort = s.cohort
group by s.cohort, s.users
order by s.cohort;
