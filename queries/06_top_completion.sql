-- Самые досматриваемые фильмы: доля просмотров, где посмотрели не меньше 90% хронометража.
-- Отсечка по числу просмотров, чтобы фильмы с парой зрителей не занимали верх.
select m.title,
       m.year,
       count(*) as views,
       round(100.0 * count(*) filter (where v.watched_min >= 0.9 * m.duration_min) / count(*), 1) as completion_pct,
       round(avg(r.score), 2) as avg_score
from kino.views v
join kino.movies m on m.id = v.movie_id and not m.is_series
left join kino.ratings r on r.user_id = v.user_id and r.movie_id = v.movie_id
group by m.id, m.title, m.year
having count(*) >= 100
order by completion_pct desc, views desc
limit 15;
