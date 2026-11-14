-- ───────── الطلبات (كل الانتقالات هنا) ─────────
create function notify(uid uuid, t text, b text, d jsonb default null) returns void
language sql security definer as $$
  insert into notifications (user_id, title, body, data) values (uid, t, b, d)
$$;

create function create_order(p_freelancer uuid, p_conv uuid, p_type text, p_desc text,
                             p_price numeric, p_days int) returns uuid
language plpgsql security definer as $$
declare me profiles; fee numeric(12,2); oid uuid;
begin
  select * into me from profiles where id = auth.uid();
  if me.role <> 'client' or me.status = 'banned' then raise exception 'غير مسموح'; end if;
  fee := round(p_price * 0.05, 2);
  insert into orders (client_id, freelancer_id, conversation_id, service_type, description, price,
                      duration_days, fee_client, fee_freelancer, client_total, freelancer_net)
  values (auth.uid(), p_freelancer, p_conv, p_type, p_desc, p_price, p_days,
          fee, fee, p_price + fee, p_price - fee)
  returning id into oid;
  return oid;
end $$;

create function submit_payment_proof(p_order uuid, p_path text) returns void
language plpgsql security definer as $$
begin
  update orders set payment_proof_path = p_path, state = 'payment_review'
  where id = p_order and client_id = auth.uid() and state in ('awaiting_payment','payment_review');
  if not found then raise exception 'طلب غير صالح'; end if;
end $$;

create function admin_review_payment(p_order uuid, p_ok boolean) returns void
language plpgsql security definer as $$
declare o orders;
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into o from orders where id = p_order and state = 'payment_review' for update;
  if not found then raise exception 'الطلب ليس قيد المراجعة'; end if;
  if p_ok then
    update orders set state='pending_accept', payment_confirmed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount) values (p_order,'payment_in',o.client_total);
    perform notify(o.freelancer_id,'طلب مشروع جديد','لديك طلب جديد بانتظار موافقتك',jsonb_build_object('order',p_order));
  else
    update orders set state='awaiting_payment', payment_proof_path=null where id=p_order;
    perform notify(o.client_id,'تعذر تأكيد الدفع','يرجى رفع إثبات صحيح',jsonb_build_object('order',p_order));
  end if;
end $$;

create function freelancer_respond(p_order uuid, p_accept boolean) returns void
language plpgsql security definer as $$
declare o orders;
begin
  select * into o from orders where id=p_order and freelancer_id=auth.uid() and state='pending_accept' for update;
  if not found then raise exception 'غير مسموح'; end if;
  if p_accept then
    update orders set state='in_progress', accepted_at=now(),
           due_at = now() + make_interval(days => duration_days) where id=p_order;
    perform notify(o.freelancer_id,'ابدأ العمل','تم تأكيد الدفع وقبول الطلب',jsonb_build_object('order',p_order));
    perform notify(o.client_id,'تم قبول طلبك','بدأ مقدم الخدمة العمل',jsonb_build_object('order',p_order));
  else
    update orders set state='refunded', completed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount, note) values (p_order,'refund',o.client_total,'رفض المستقل');
    perform notify(o.client_id,'اعتذار عن الطلب','اعتذر مقدم الخدمة وسيُعاد مبلغك كاملاً',jsonb_build_object('order',p_order));
  end if;
end $$;

create function deliver_order(p_order uuid, p_desc text, p_links text[], p_files text[]) returns void
language plpgsql security definer as $$
begin
  update orders set state='delivered', delivered_at=now(), auto_release_at=now()+interval '24 hours'
  where id=p_order and freelancer_id=auth.uid() and state='in_progress';
  if not found then raise exception 'غير مسموح'; end if;
  insert into deliveries (order_id, description, links, files) values (p_order,p_desc,p_links,p_files);
end $$;
