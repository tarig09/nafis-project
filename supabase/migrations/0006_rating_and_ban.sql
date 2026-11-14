-- ───────── التقييم والحظر ─────────
create function rate_order(p_order uuid, p_stars int) returns void
language plpgsql security definer as $$
declare o orders; created timestamptz;
begin
  select * into o from orders where id=p_order and client_id=auth.uid() and state='completed';
  if not found then raise exception 'لا يمكن التقييم'; end if;
  select created_at into created from profiles where id=auth.uid();
  if created > now() - interval '7 days' then raise exception 'يجب أن يمر 7 أيام على إنشاء الحساب'; end if;
  insert into ratings (order_id, client_id, freelancer_id, stars) values (p_order, auth.uid(), o.freelancer_id, p_stars);
end $$;

create function after_rating() returns trigger language plpgsql security definer as $$
declare avg_ numeric; cnt int;
begin
  select avg(stars), count(*) into avg_, cnt from ratings where freelancer_id = new.freelancer_id;
  update profiles set rating_avg = round(avg_,2), rating_count = cnt where id = new.freelancer_id;
  -- حد التقييم <= 2.0 (انظر السؤال #6 بخصوص حد أدنى لعدد التقييمات)
  if avg_ <= 2.0 then perform flag_for_ban(new.freelancer_id,'انخفاض التقييم'); end if;
  return new;
end $$;
create trigger trg_after_rating after insert on ratings for each row execute function after_rating();

-- تحذير رسمي أولاً؛ الحظر النهائي بيد الإدارة بعد طلب المراجعة
create function flag_for_ban(uid uuid, why text) returns void language plpgsql security definer as $$
begin
  update profiles set status='warned' where id=uid and status='active';
  if found then perform notify(uid,'تحذير رسمي', why || '. يمكنك طلب مراجعة يدوية من الإدارة'); end if;
end $$;

create function after_report_update() returns trigger language plpgsql security definer as $$
declare delivery_cnt int; other_cnt int;
begin
  if new.status = 'confirmed' then
    select count(*) filter (where category='delivery'), count(*) filter (where category<>'delivery')
      into delivery_cnt, other_cnt from reports where target_id=new.target_id and status='confirmed';
    if delivery_cnt >= 5 then perform flag_for_ban(new.target_id,'5 شكاوى تسليم مؤكدة');
    elsif other_cnt >= 10 then perform flag_for_ban(new.target_id,'10 بلاغات مؤكدة'); end if;
  end if;
  return new;
end $$;
create trigger trg_after_report after update on reports for each row execute function after_report_update();

create function admin_set_status(uid uuid, s account_status) returns void language plpgsql security definer as $$
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  update profiles set status = s where id = uid;
end $$;
