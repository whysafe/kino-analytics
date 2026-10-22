-- Генератор данных за 2025 год на чистом SQL. setseed делает результат воспроизводимым:
-- одинаковые цифры в отчётах у всех, кто запустит скрипт. Параллельные планы отключены,
-- потому что они меняют порядок вызова random().

set search_path = kino;
set max_parallel_workers_per_gather = 0;
select setseed(0.42);

insert into plans values
    (0, 'Пробный', 0),
    (1, 'Базовый', 299),
    (2, 'Стандарт', 499),
    (3, 'Премиум', 799);

insert into genres values
    (1, 'Драма'), (2, 'Комедия'), (3, 'Триллер'), (4, 'Фантастика'), (5, 'Детектив'),
    (6, 'Мелодрама'), (7, 'Мультфильм'), (8, 'Документальный'), (9, 'Ужасы'), (10, 'Приключения');

-- 400 тайтлов: каждый пятый — сериал (длительность серии 25–55 минут), остальные — фильмы 80–160 минут.
insert into movies (id, title, year, duration_min, is_series)
select
    n,
    (array['Тихий', 'Северный', 'Последний', 'Красный', 'Долгий', 'Чужой', 'Ночной', 'Стеклянный',
           'Летний', 'Дикий', 'Белый', 'Старый'])[1 + (n * 7) % 12]
      || ' ' ||
    (array['берег', 'город', 'рейс', 'ветер', 'сад', 'код', 'маяк', 'перевал', 'след', 'остров',
           'вокзал', 'архив', 'шторм', 'квартал'])[1 + (n * 11) % 14]
      || case when n > 168 then ' ' || (n / 168 + 1)::text else '' end,
    (1975 + floor(random() * 51))::smallint,
    case when n % 5 = 0 then (25 + floor(random() * 31))::smallint else (80 + floor(random() * 81))::smallint end,
    n % 5 = 0
from generate_series(1, 400) n;

-- 1–3 жанра на тайтл, первый жанр зависит от номера, чтобы у жанров были разные размеры каталога.
insert into movie_genres
select distinct m.id, g.genre_id
from movies m
cross join lateral (
    select (1 + (m.id * 3) % 10)::smallint as genre_id
    union all
    select (1 + floor(random() * 10))::smallint where random() < 0.6
    union all
    select (1 + floor(random() * 10))::smallint where random() < 0.25
) g;

-- 5000 пользователей, регистраций к концу года становится больше (sqrt даёт рост).
insert into users (email, city, device, signed_up)
select
    'user' || n || '@example.com',
    (array['Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань', 'Краснодар', 'Самара', 'Пермь'])
        [1 + floor(power(random(), 1.6) * 8)::int],
    (array['tv', 'mobile', 'web'])[1 + floor(random() * 3)::int],
    date '2025-01-01' + floor(sqrt(random()) * 365)::int
from generate_series(1, 5000) n;

-- Пробная неделя у всех.
insert into subscriptions (user_id, plan_id, started_on, ended_on)
select id, 0, signed_up, signed_up + 6 from users;

-- 58% переходят на платный тариф. Срок жизни подписки — геометрическое распределение по месяцам
-- (отток около 9% в месяц). Если подписка дожила до конца года, она активна (ended_on = null).
insert into subscriptions (user_id, plan_id, started_on, ended_on)
select user_id,
       case when r < 0.5 then 1 when r < 0.85 then 2 else 3 end::smallint,
       started_on,
       case when ends <= date '2025-12-31' then ends end
from (
    -- random() в списке выборки вычисляется для каждой строки; в некоррелированном LATERAL он посчитался бы один раз
    select u.id as user_id, u.signed_up + 7 as started_on, random() as r, random() as convert,
           (u.signed_up + 7 + make_interval(months => 1 + floor(-ln(1 - random()) / 0.094)::int))::date - 1 as ends
    from users u
    where u.signed_up + 7 <= date '2025-12-31'
) s
where convert < 0.58;

-- Ежемесячные платежи по платным подпискам до конца подписки или года.
insert into payments (subscription_id, paid_on, amount)
select s.id, d::date, p.monthly_price
from subscriptions s
join plans p on p.id = s.plan_id
cross join lateral generate_series(s.started_on, coalesce(s.ended_on, date '2025-12-31'), interval '1 month') d
where s.plan_id > 0;

-- Активное окно пользователя: от регистрации до конца последней подписки.
create temporary table activity as
select u.id as user_id, u.signed_up as first_day,
       case when bool_or(s.ended_on is null) then date '2025-12-31'
            else least(max(s.ended_on), date '2025-12-31') end as last_day,
       0.15 + random() * 0.9 as sessions_per_day
from users u
join subscriptions s on s.user_id = u.id
group by u.id, u.signed_up;

-- Просмотры: популярные тайтлы смотрят чаще (random()^2 сдвигает выбор к малым id).
-- Досматриваемость зависит от «качества» тайтла, которое модель не видит напрямую.
insert into views (user_id, movie_id, started_at, watched_min)
select x.user_id, m.id,
       (x.first_day + floor(x.r_day * (x.last_day - x.first_day + 1))::int)::timestamp
           + make_interval(hours => 17 + floor(x.r_hour * 7)::int, mins => floor(x.r_min * 60)::int),
       greatest(1, round(m.duration_min * least(1, greatest(0.05,
           0.45 + 0.4 * ((m.id * 37) % 100) / 100.0 + (x.r_done - 0.5) * 0.7))))::smallint
from (
    select a.user_id, a.first_day, a.last_day,
           1 + floor(power(random(), 2) * 400)::int as movie_id,
           random() as r_day, random() as r_hour, random() as r_min, random() as r_done
    from activity a
    cross join lateral generate_series(1, greatest(1, ((a.last_day - a.first_day + 1) * a.sessions_per_day)::int)) k
) x
join movies m on m.id = x.movie_id
-- Вставка по времени, как в живой системе: на этом держится BRIN-индекс по started_at.
order by 3;

-- Запойный просмотр сериалов: после части серий человек смотрит ещё 2–5 серий подряд.
insert into views (user_id, movie_id, started_at, watched_min)
select p.user_id, p.movie_id, p.started_at + make_interval(mins => (p.duration_min + 3) * k), p.duration_min
from (
    select v.user_id, v.movie_id, v.started_at, m.duration_min, 2 + floor(random() * 4)::int as extra, random() as r
    from views v
    join movies m on m.id = v.movie_id and m.is_series
) p
cross join lateral generate_series(1, p.extra) k
where p.r < 0.3;

-- Оценки ставят примерно четверть досмотревших; оценка связана с тем же «качеством» тайтла.
insert into ratings (user_id, movie_id, score, rated_on)
select distinct on (v.user_id, v.movie_id)
       v.user_id, v.movie_id,
       least(10, greatest(1, round(4 + 5 * ((v.movie_id * 37) % 100) / 100.0 + (random() - 0.5) * 3)))::smallint,
       v.started_at::date
from views v
join movies m on m.id = v.movie_id
where v.watched_min >= 0.8 * m.duration_min and random() < 0.25
order by v.user_id, v.movie_id, v.started_at;

analyze;
