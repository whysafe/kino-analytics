-- Запойный просмотр: три и больше серий одного сериала подряд с перерывами не длиннее 15 минут.
-- Техника gaps-and-islands: lag() находит разрывы, накопительная сумма разрывов нумерует «острова».
with ordered as (
    select v.user_id, v.movie_id, v.started_at,
           v.started_at + make_interval(mins => v.watched_min) as ended_at,
           lag(v.started_at + make_interval(mins => v.watched_min))
               over (partition by v.user_id, v.movie_id order by v.started_at) as prev_end
    from kino.views v
    join kino.movies m on m.id = v.movie_id and m.is_series
),
marked as (
    select *,
           case when prev_end is null or started_at - prev_end > interval '15 minutes' then 1 else 0 end as new_session
    from ordered
),
sessions as (
    select user_id, movie_id, started_at, ended_at,
           sum(new_session) over (partition by user_id, movie_id order by started_at) as session_n
    from marked
),
binges as (
    select user_id, movie_id, session_n,
           count(*) as episodes,
           min(started_at) as from_at,
           max(ended_at) as to_at
    from sessions
    group by user_id, movie_id, session_n
    having count(*) >= 3
)
select m.title,
       count(*) as binges,
       count(distinct b.user_id) as bingers,
       round(avg(b.episodes), 1) as avg_episodes,
       max(b.episodes) as max_episodes,
       to_char(avg(b.to_at - b.from_at), 'HH24:MI') as avg_duration
from binges b
join kino.movies m on m.id = b.movie_id
group by m.id, m.title
order by binges desc, m.title
limit 10;
