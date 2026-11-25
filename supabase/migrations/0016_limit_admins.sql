-- حد أقصى حسابان إداريان
create or replace function limit_admins() returns trigger language plpgsql as $$
begin
  if (select count(*) from admins) >= 2 then
    raise exception 'الحد الأقصى حسابان إداريان فقط';
  end if;
  return new;
end $$;

drop trigger if exists trg_limit_admins on admins;
create trigger trg_limit_admins before insert on admins
  for each row execute function limit_admins();
