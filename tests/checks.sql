-- Проверки целостности данных и правдоподобия аналитики. Любая ошибка останавливает CI.
-- Запуск: psql -v ON_ERROR_STOP=1 -f tests/checks.sql

set search_path = kino;

create or replace function pg_temp.check(ok boolean, message text) returns void language plpgsql as $$
begin
    if not coalesce(ok, false) then
        raise exception 'ПРОВЕРКА НЕ ПРОЙДЕНА: %', message;
    end if;
    raise notice 'ok: %', message;
end $$;

-- Объём данных
select pg_temp.check((select count(*) from users) = 5000, 'пользователей ровно 5000');
select pg_temp.check((select count(*) from movies) = 400, 'тайтлов 400');
select pg_temp.check((select count(*) from views) between 100000 and 2000000, 'просмотров от 100 тыс. до 2 млн');
select pg_temp.check(not exists (select 1 from movies m where not exists (
    select 1 from movie_genres g where g.movie_id = m.id)), 'у каждого тайтла есть жанр');

-- Подписки и платежи
select pg_temp.check(not exists (
    select user_id from subscriptions where plan_id = 0 group by user_id having count(*) <> 1
) and (select count(*) from subscriptions where plan_id = 0) = 5000, 'у каждого ровно одна пробная неделя');
select pg_temp.check(not exists (
    select 1 from subscriptions a join subscriptions b
      on a.user_id = b.user_id and a.id < b.id
     and daterange(a.started_on, a.ended_on, '[]') && daterange(b.started_on, b.ended_on, '[]')
), 'подписки одного человека не пересекаются');
select pg_temp.check(not exists (
    select 1 from payments p join subscriptions s on s.id = p.subscription_id
    where s.plan_id = 0 or p.paid_on < s.started_on or p.paid_on > coalesce(s.ended_on, date '2025-12-31')
), 'платежи только по платным подпискам и внутри их срока');
select pg_temp.check(not exists (
    select 1 from payments p join subscriptions s on s.id = p.subscription_id join plans pl on pl.id = s.plan_id
    where p.amount <> pl.monthly_price
), 'сумма платежа равна цене тарифа');

-- Просмотры
select pg_temp.check(not exists (
    select 1 from views v join users u on u.id = v.user_id where v.started_at::date < u.signed_up
), 'никто не смотрит до регистрации');
select pg_temp.check(not exists (
    select 1 from views v join movies m on m.id = v.movie_id where v.watched_min > m.duration_min
), 'посмотрено не больше хронометража');
select pg_temp.check(not exists (
    select 1 from ratings r where not exists (
        select 1 from views v where v.user_id = r.user_id and v.movie_id = r.movie_id)
), 'оценки ставят только те, кто смотрел');

-- Правдоподобие аналитики (числа заложены в генератор, проверяем, что запросы их «видят»)
select pg_temp.check((
    select 100.0 * count(*) filter (where exists (
        select 1 from subscriptions s where s.user_id = u.id and s.plan_id > 0)) / count(*)
    from users u where u.signed_up <= date '2025-12-24'
) between 52 and 64, 'конверсия из пробной недели около 58%');
select pg_temp.check((
    with months as (select generate_series(date '2025-03-01', date '2025-12-01', interval '1 month')::date m)
    select avg(churn) from (
        select 100.0 * count(*) filter (where s.ended_on < (m + interval '1 month')::date) / count(*) as churn
        from months join subscriptions s on s.plan_id > 0 and s.started_on < m and (s.ended_on is null or s.ended_on >= m)
        group by m
    ) x
) between 5 and 14, 'месячный отток платных подписок около 9%');
select pg_temp.check((select sum(amount) from payments) = (
    select sum(revenue) from (
        select sum(p.amount) as revenue from payments p group by date_trunc('month', p.paid_on)
    ) x
), 'помесячная выручка в сумме равна всем платежам');
select pg_temp.check((
    with c as (
        select m.id, avg(v.watched_min::numeric / m.duration_min) as completion
        from movies m join views v on v.movie_id = m.id group by m.id
    ), s as (
        select movie_id, avg(score) as score from ratings group by movie_id having count(*) >= 20
    )
    select corr(c.completion, s.score) from c join s on s.movie_id = c.id
) > 0.5, 'оценка и досматриваемость заметно связаны (corr > 0.5)');
select pg_temp.check((
    select count(*) from (
        select v.user_id, v.movie_id, v.started_at,
               v.started_at - lag(v.started_at + make_interval(mins => v.watched_min))
                   over (partition by v.user_id, v.movie_id order by v.started_at) as gap
        from views v join movies m on m.id = v.movie_id and m.is_series
    ) x where gap between interval '0' and interval '15 minutes'
) > 1000, 'запойные просмотры сериалов есть в данных');

-- Индексы: запрос «кого возвращать» должен идти по индексу просмотров, а не полным перебором
create temporary table plan_text (line text);
do $$
declare r record;
begin
    for r in execute 'explain select 1 from kino.views where user_id = 42 and started_at >= timestamptz ''2025-12-18''' loop
        insert into plan_text values (r."QUERY PLAN");
    end loop;
end $$;
select pg_temp.check(exists (select 1 from plan_text where line like '%views_user_time_idx%'),
                     'поиск просмотров пользователя идёт по индексу views_user_time_idx');
