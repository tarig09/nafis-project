# نَافِس (Nafis) — in sudan

منصة سودانية تجمع بين التواصل الاجتماعي وسوق العمل الحر، لتنظيم السوق، ومحاربة ادعاء الخبرة، وفتح فرص حقيقية للمواهب.

## الحالة
🚧 مرحلة التأسيس (قبل MVP)

## أهم المبادئ
- الدخول حصرياً عبر Google. الأفراد والفرق فقط، بلا شركات.
- نوعان من الحسابات: **مقدم خدمة** و**طالب خدمة**.
- التوثيق مجاني ويدوي بمراجعة الإدارة.
- الصفقة تبقى داخل المنصة: الدردشة نصية فقط، بلا روابط أو أرقام.
- الدفع يدوي عبر بنكك مع ضمان (Escrow) تديره الإدارة.
- عمولة 10% (5% عميل + 5% مقدم خدمة).

## التقنيات
| الطبقة | الاختيار |
|---|---|
| تطبيق الموبايل | Flutter (Android أولاً) |
| الخلفية | **Supabase**: Auth (Google)، Postgres + RLS، Realtime، Storage، Edge Functions، pg_cron |
| الإشعارات الخارجية | FCM عبر Edge Function (`push-notify`) |
| لوحة الإدارة | React + Vite (ويب) |
| CI | GitHub Actions |

## هيكل المستودع
```
app/                       تطبيق Flutter
admin/                     لوحة الإدارة (مراجعة الدفع، التوثيق، الشكاوى، الحظر)
supabase/migrations/       مخطط قاعدة البيانات + RLS + دوال الطلبات
supabase/functions/        Edge Functions (push-notify, chat-unread-notifier)
docs/                      المتطلبات والمعمارية ونموذج البيانات
scripts/                   أدوات مساعدة (إنشاء Issues)
```

## الوثائق
1. [المتطلبات](docs/01-requirements.md)
2. [المعمارية](docs/02-architecture.md)
3. [نموذج البيانات](docs/03-data-model.md)
4. [دورة حياة الطلب](docs/04-order-state-machine.md)
5. [خارطة الطريق](docs/05-roadmap.md)
6. [أسئلة مفتوحة](docs/06-open-questions.md)

## تشغيل Supabase
```bash
npm i -g supabase
supabase init            # ينشئ config.toml فقط ولا يمس migrations
supabase link --project-ref <PROJECT_REF>
supabase db push         # يطبق supabase/migrations/0001_init.sql
```
ثم من لوحة Supabase: فعّل Google في Auth، وفعّل إضافة `pg_cron`، وأضف نفسك مديراً:
```sql
insert into admins (user_id) values ('<UUID حسابك من auth.users>');
```

## البدء
```bash
git init && git add . && git commit -m "chore: initial project scaffold"
gh repo create nafis --private --source=. --push
bash scripts/create_issues.sh
```
