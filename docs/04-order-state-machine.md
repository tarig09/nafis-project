# دورة حياة الطلب

```mermaid
stateDiagram-v2
  [*] --> AWAITING_PAYMENT: العميل ينشئ الطلب
  AWAITING_PAYMENT --> PAYMENT_REVIEW: رفع إثبات التحويل
  PAYMENT_REVIEW --> AWAITING_PAYMENT: الإدارة ترفض الإثبات
  PAYMENT_REVIEW --> PENDING_ACCEPT: الإدارة تؤكد الدفع (≤24س)
  PENDING_ACCEPT --> IN_PROGRESS: المستقل يقبل
  PENDING_ACCEPT --> REFUNDED: المستقل يرفض (استرداد كامل)
  IN_PROGRESS --> DELIVERED: تسليم رسمي
  DELIVERED --> COMPLETED: العميل يقبل (+تقييم) أو مرور 24س دون تفاعل
  DELIVERED --> DISPUTED: شكوى تسليم
  DISPUTED --> COMPLETED: مطابقة ≥70%
  DISPUTED --> REFUNDED: مطابقة ≤50%
  COMPLETED --> [*]
  REFUNDED --> [*]
```

## قواعد
- الانتقالات تتم في Cloud Functions فقط، ولا يكتب العميل `state` مباشرة.
- يبدأ العداد التنازلي عند `IN_PROGRESS`.
- «الاسترداد الكامل» عند رفض المستقل يشمل عمولة العميل (5%).
