-- Онлайн-кинотеатр по подписке: пользователи, тарифы, подписки, платежи, каталог, просмотры и оценки.

drop schema if exists kino cascade;
create schema kino;
set search_path = kino;

create table plans (
    id            smallint primary key,
    name          text           not null unique,
    monthly_price numeric(8, 2)  not null check (monthly_price >= 0)
);

create table users (
    id          bigint generated always as identity primary key,
    email       text        not null unique,
    city        text        not null,
    device      text        not null check (device in ('tv', 'mobile', 'web')),
    signed_up   date        not null
);

-- Подписка — непрерывный период на одном тарифе. Пробный период бесплатный (plan_id = 0).
create table subscriptions (
    id          bigint generated always as identity primary key,
    user_id     bigint   not null references users (id),
    plan_id     smallint not null references plans (id),
    started_on  date     not null,
    ended_on    date,                       -- null: подписка активна
    check (ended_on is null or ended_on >= started_on)
);

create table payments (
    id              bigint generated always as identity primary key,
    subscription_id bigint        not null references subscriptions (id),
    paid_on         date          not null,
    amount          numeric(8, 2) not null check (amount > 0)
);

create table genres (
    id   smallint primary key,
    name text not null unique
);

create table movies (
    id           int primary key,
    title        text     not null,
    year         smallint not null check (year between 1920 and 2030),
    duration_min smallint not null check (duration_min between 1 and 400),
    is_series    boolean  not null default false
);

create table movie_genres (
    movie_id int      not null references movies (id),
    genre_id smallint not null references genres (id),
    primary key (movie_id, genre_id)
);

-- Сеанс просмотра: сколько минут посмотрели из длительности фильма или серии.
create table views (
    id          bigint generated always as identity primary key,
    user_id     bigint      not null references users (id),
    movie_id    int         not null references movies (id),
    started_at  timestamptz not null,
    watched_min smallint    not null check (watched_min > 0)
);

create table ratings (
    user_id  bigint   not null references users (id),
    movie_id int      not null references movies (id),
    score    smallint not null check (score between 1 and 10),
    rated_on date     not null,
    primary key (user_id, movie_id)
);

-- Индексы под аналитические запросы (см. README: что каждый из них ускоряет).
create index views_user_time_idx on views (user_id, started_at);
create index views_movie_idx on views (movie_id);
create index views_time_brin on views using brin (started_at);
create index subscriptions_user_idx on subscriptions (user_id, started_on);
create index subscriptions_active_idx on subscriptions (user_id) where ended_on is null;
create index payments_date_idx on payments (paid_on);
