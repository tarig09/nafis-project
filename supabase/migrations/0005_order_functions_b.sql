create function _release(p_order uuid) returns void language plpgsql as $$
declare o orders;
begin
  select * into o from orders where id=p_order;
  update orders set state='completed', completed_at=now() where id=p_order;
  insert into ledger_entries (order_id, kind, amount) values
    (p_order,'release',o.freelancer_net),(p_order,'platform_fee',o.fee_client+o.fee_freelancer);
  perform notify(o.freelancer_id,'تم تحويل مستحقاتك','اكتمل الطلب',jsonb_build_object('order',p_order));
end $$;

create function client_accept_delivery(p_order uuid) returns void
language plpgsql security definer as $$
begin
  perform 1 from orders where id=p_order and client_id=auth.uid() and state='delivered' for update;
  if not found then raise exception 'غير مسموح'; end if;
  perform _release(p_order);
end $$;

create function open_dispute(p_order uuid, p_reason text) returns void
language plpgsql security definer as $$
begin
  update orders set state='disputed', auto_release_at=null
  where id=p_order and client_id=auth.uid() and state='delivered';
  if not found then raise exception 'غير مسموح'; end if;
  insert into disputes (order_id, opened_by, reason) values (p_order, auth.uid(), p_reason);
  insert into reports (reporter_id, target_id, category, details)
    select client_id, freelancer_id, 'delivery', p_reason from orders where id=p_order;
end $$;

create function admin_resolve_dispute(p_order uuid, p_match int) returns void
language plpgsql security definer as $$
declare o orders;
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into o from orders where id=p_order and state='disputed' for update;
  if not found then raise exception 'ليس نزاعاً مفتوحاً'; end if;
  update disputes set match_percent=p_match, decided_by=auth.uid(), decided_at=now() where order_id=p_order;
  if p_match >= 70 then
    perform _release(p_order);
    update reports set status='dismissed' where target_id=o.freelancer_id and category='delivery' and status='open' and details is not distinct from (select reason from disputes where order_id=p_order);
  elsif p_match <= 50 then
    update orders set state='refunded', completed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount, note) values (p_order,'refund',o.client_total,'نزاع');
    update reports set status='confirmed' where target_id=o.freelancer_id and category='delivery' and status='open' and details is not distinct from (select reason from disputes where order_id=p_order);
  else
    raise exception 'النطاق 51–69%% غير محدد بعد (docs/06-open-questions.md #1)';
  end if;
end $$;

-- تحويل تلقائي بعد 24 ساعة دون تفاعل
create function auto_release_orders() returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select id from orders where state='delivered' and auto_release_at <= now() for update skip locked
  loop perform _release(r.id); end loop;
end $$;
select cron.schedule('nafis-auto-release','*/10 * * * *','select public.auto_release_orders()');

-- تنبيه اقتراب/انتهاء المدة
create function deadline_reminders() returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select id, freelancer_id from orders where state='in_progress' and due_at <= now() + interval '6 hours'
           and not exists (select 1 from notifications n where n.user_id=freelancer_id and (n.data->>'deadline')=id::text)
  loop perform notify(r.freelancer_id,'اقترب موعد التسليم','انتهى الوقت أو اقترب، يرجى تسليم العمل',
                      jsonb_build_object('order',r.id,'deadline',r.id)); end loop;
end $$;
select cron.schedule('nafis-deadlines','*/30 * * * *','select public.deadline_reminders()');
