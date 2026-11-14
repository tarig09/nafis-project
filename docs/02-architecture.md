# المعمارية (Supabase)

```
Flutter App ──► Supabase Auth (Google OAuth)
     │          Postgres + RLS  (البيانات، دوال الطلبات RPC)
     │          Realtime        (الدردشة، الإشعارات الداخلية)
     │          Storage         (صور، إثباتات دفع، ملفات تسليم)
Admin (React) ─► نفس المشروع، حساب موجود في جدول admins
pg_cron ───────► auto_release_orders (كل 10 د) · deadline_reminders (كل 30 د)
Edge Functions ► push-notify (FCM) · chat-unread-notifier
```

## مبدأ أساسي
التطبيق **لا يكتب** حالة الطلب أو المبالغ مباشرة. كل انتقال عبر دالة RPC من نوع `security definer`:

| الدالة | من يستدعيها |
|---|---|
| `create_order` | العميل |
| `submit_payment_proof` | العميل |
| `admin_review_payment` | الإدارة |
| `freelancer_respond` | المستقل |
| `deliver_order` | المستقل |
| `client_accept_delivery` / `open_dispute` | العميل |
| `admin_resolve_dispute` | الإدارة |
| `rate_order` | العميل |
| `auto_release_orders` / `deadline_reminders` | pg_cron |

## أين تتحقق القواعد؟
| القاعدة | المكان |
|---|---|
| منع الروابط والأرقام (دردشة/منشورات) | Triggers في Postgres (`violates_contact_rule`) |
| الخلاصة (7 أيام، المتابَعون أولاً، التثبيت 24س) | `get_feed()` |
| البحث (30 يوماً) | `search_posts()` |
| العمولة 5% + 5% | داخل `create_order` |
| الحظر: تحذير ثم قرار الإدارة | `flag_for_ban` + `admin_set_status` |
| صلاحيات الأدوار | RLS + Triggers |

## Edge Functions
- `push-notify`: يُستدعى بـ Database Webhook عند إدخال صف في `notifications` ويرسل FCM لرموز `device_tokens`.
- `chat-unread-notifier`: مجدولة كل دقيقة؛ تُنشئ إشعاراً لرسائل `seen_at is null` و`notified_at is null` عمرها ≥ 5 دقائق، ثم تعبّئ `notified_at`.

## ملاحظات أمان
- لا تضع `service_role key` في التطبيق إطلاقاً.
- مسارات Storage الخاصة تُقيَّد بسياسات (صاحب الملف + الإدارة).
- فحص الصور بحثاً عن أرقام/روابط: يدوي في MVP (OCR لاحقاً).
- المنشورات ذات رابط معرض الأعمال تبقى `pending` حتى موافقة الإدارة (يُنفّذ في الواجهة/لوحة الإدارة).
