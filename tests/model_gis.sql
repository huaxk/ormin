create table if not exists place(
  id serial primary key,
  name varchar not null,
  lnglat geometry
);