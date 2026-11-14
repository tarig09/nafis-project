# نموذج البيانات

المصدر الرسمي: مجلد `supabase/migrations` (الملفات 0001 إلى 0008 بالترتيب).

## الجداول
`profiles` · `admins` · `follows` · `posts` · `conversations` · `messages` · `orders` · `deliveries` · `disputes` · `ledger_entries` · `ratings` · `reports` · `verification_requests` · `feedback` · `notifications` · `device_tokens`

## قرارات تصميم
- `profiles.role` يُختار بعد أول دخول (قبلها `null`).
- المحادثة بين مستخدمين فقط: `user_a < user_b` مع `unique` لمنع التكرار.
- `orders` يخزّن `fee_client` و`fee_freelancer` و`client_total` و`freelancer_net` عند الإنشاء ولا يتغير.
- `ledger_entries` سجل محاسبي لكل حركة مال (دخل، تحويل، استرداد، عمولة) لأن المال يُدار يدوياً.
- `ratings.order_id` مفتاح أساسي ⇒ تقييم واحد لكل طلب.
- لا يوجد تقييم للعملاء ولا حقل تقييم يُعرض لحساب العميل.

## تنبيه
نطاق التحكيم 51–69% يُرفع منه استثناء صريح في `admin_resolve_dispute` حتى يُحسم القرار (راجع `06-open-questions.md`).
