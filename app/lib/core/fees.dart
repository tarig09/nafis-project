/// العمولة 10% مقسومة: 5% على العميل و5% على مقدم الخدمة.
class OrderAmounts {
  final double price;
  final double feeEach;
  final double clientTotal;
  final double freelancerNet;
  final double platformFee;
  const OrderAmounts(this.price, this.feeEach, this.clientTotal,
      this.freelancerNet, this.platformFee);
}

OrderAmounts calcAmounts(double price) {
  final fee = (price * 0.05 * 100).round() / 100;
  return OrderAmounts(price, fee, price + fee, price - fee, fee * 2);
}
