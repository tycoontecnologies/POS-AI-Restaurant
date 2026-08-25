import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/routes/app_router.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  static const burgundy = Color(0xFF7A1026);
  static const ink = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1300 ? 4 : width > 800 ? 2 : 1;
    final cardWidth = columns == 4 ? (width - 140) / 4 : columns == 2 ? (width - 90) / 2 : width - 48;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: () => context.go(AppRouter.dashboard), icon: const Icon(Icons.arrow_back_rounded)),
            const SizedBox(width: 6),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Choose your Tycoon POS package', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink)),
              SizedBox(height: 3),
              Text('Your selected package controls billing while your restaurant data and workflow remain the same.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(width: cardWidth, child: _PlanCard(title: 'Pay per Transaction', price: 'Rs 1', period: 'per successful receipt', icon: Icons.receipt_long_outlined, features: const ['Only successful receipts are charged', 'Cancelled receipts are not charged', 'Usage counter visible to restaurant admin', 'Full POS feature access'], onSelect: () => _goPayment(context, 'perTransaction'))),
            SizedBox(width: cardWidth, child: _PlanCard(title: 'Monthly', price: 'Rs 7,000', period: 'per month', icon: Icons.calendar_month_outlined, features: const ['Full POS feature access', 'Payment window opens on the 25th', 'Pay by month-end to avoid downgrade', 'Support and updates included'], onSelect: () => _goPayment(context, 'monthly'), popular: true)),
            SizedBox(width: cardWidth, child: _PlanCard(title: 'Yearly', price: 'Rs 80,000', period: 'per year', icon: Icons.workspace_premium_outlined, features: const ['Normal annual value: Rs 84,000', 'Special annual charge: Rs 80,000', 'Full POS feature access', 'Support and updates included'], onSelect: () => _goPayment(context, 'yearly'))),
            SizedBox(width: cardWidth, child: _PlanCard(title: '5 Years', price: 'Rs 200,000', period: 'five-year package', icon: Icons.verified_outlined, features: const ['Five years of package access', 'No monthly package fee during term', 'Full POS feature access', 'Long-term value package'], onSelect: () => _goPayment(context, 'fiveYears'))),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: burgundy, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Monthly customers are notified from the 25th. If the monthly fee remains unpaid after the due date, the account is automatically moved to Basic Mode until payment is recorded.', style: TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF475569)))),
            ]),
          ),
        ]),
      ),
    );
  }

  static void _goPayment(BuildContext context, String plan) => context.go('${AppRouter.payment}/$plan');
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final IconData icon;
  final List<String> features;
  final VoidCallback onSelect;
  final bool popular;
  const _PlanCard({required this.title, required this.price, required this.period, required this.icon, required this.features, required this.onSelect, this.popular = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 360),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: popular ? PricingScreen.burgundy : const Color(0xFFE2E8F0), width: popular ? 1.5 : 1), boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFBECEF), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: PricingScreen.burgundy, size: 22)),
          const Spacer(),
          if (popular) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFBECEF), borderRadius: BorderRadius.circular(14)), child: const Text('POPULAR', style: TextStyle(fontSize: 9, color: PricingScreen.burgundy, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: PricingScreen.ink)),
        const SizedBox(height: 10),
        Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: PricingScreen.ink)),
        Text(period, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 20),
        ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 17), const SizedBox(width: 8), Expanded(child: Text(f, style: const TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF475569))))]))),
        const Spacer(),
        SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: onSelect, style: FilledButton.styleFrom(backgroundColor: PricingScreen.burgundy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), child: const Text('Select package', style: TextStyle(fontWeight: FontWeight.w900)))),
      ]),
    );
  }
}
