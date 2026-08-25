enum BillingPlanType { perTransaction, monthly, yearly, fiveYears }

class BillingPlan {
  final BillingPlanType type;
  final String title;
  final int price;
  final int? regularPrice;
  final String period;
  final String description;

  const BillingPlan({
    required this.type,
    required this.title,
    required this.price,
    this.regularPrice,
    required this.period,
    required this.description,
  });

  String get id => type.name;

  static const plans = <BillingPlan>[
    BillingPlan(
      type: BillingPlanType.perTransaction,
      title: 'Pay Per Transaction',
      price: 1,
      period: 'successful receipt',
      description: 'Rs 1 per successful receipt. Cancelled receipts are not charged.',
    ),
    BillingPlan(
      type: BillingPlanType.monthly,
      title: 'Monthly',
      price: 7000,
      period: 'month',
      description: 'Full Tycoon POS subscription billed monthly.',
    ),
    BillingPlan(
      type: BillingPlanType.yearly,
      title: 'Yearly',
      price: 80000,
      regularPrice: 84000,
      period: 'year',
      description: 'Save Rs 4,000 compared with monthly billing.',
    ),
    BillingPlan(
      type: BillingPlanType.fiveYears,
      title: '5 Years',
      price: 200000,
      period: '5 years',
      description: 'Long-term package with five years of access.',
    ),
  ];

  static BillingPlan byId(String id) => plans.firstWhere(
        (p) => p.id == id,
        orElse: () => plans.first,
      );
}
