import 'package:flutter_test/flutter_test.dart';
import 'package:nafis/core/fees.dart';

void main() {
  test('العمولة: سعر 40 → العميل 42، المستقل 38، المنصة 4', () {
    final a = calcAmounts(40);
    expect(a.clientTotal, closeTo(42, 0.001));
    expect(a.freelancerNet, closeTo(38, 0.001));
    expect(a.platformFee, closeTo(4, 0.001));
  });
}
