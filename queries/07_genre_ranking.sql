-- Лидеры жанров по кварталам: часы просмотра, место жанра и его доля в квартале.
-- Техника: dense_rank() в окне по кварталу и доля от суммы окна.
with hours as (
    select date_trunc('quarter', v.started_at)::date as quarter,
           g.name as genre,
           sum(v.watched_min) / 60.0 as hours
    from kino.views v
    join kino.movie_genres mg on mg.movie_id = v.movie_id
    join kino.genres g on g.id = mg.genre_id
    where v.started_at < timestamptz '2026-01-01'
    group by 1, 2
)
select 'Q' || extract(quarter from quarter) as quarter,
       dense_rank() over (partition by quarter order by hours desc) as place,
       genre,
       round(hours) as hours,
       round(100 * hours / sum(hours) over (partition by quarter), 1) as share_pct
from hours
order by quarter, place;
