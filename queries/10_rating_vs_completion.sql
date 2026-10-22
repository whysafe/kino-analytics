-- Связана ли оценка фильма с тем, досматривают ли его: корреляция Пирсона по фильмам.
-- Техника: агрегат corr() поверх агрегатов по каждому фильму.
with completion as (
    select m.id, avg(v.watched_min::numeric / m.duration_min) as completion
    from kino.movies m
    join kino.views v on v.movie_id = m.id
    group by m.id
),
scores as (
    select movie_id, avg(score) as score, count(*) as ratings
    from kino.ratings
    group by movie_id
)
select count(*) as movies,
       round(corr(c.completion, s.score)::numeric, 3) as correlation,
       round(avg(s.score), 2) as avg_score,
       round(100 * avg(c.completion), 1) as avg_completion_pct
from completion c
join scores s on s.movie_id = c.id
where s.ratings >= 20;
