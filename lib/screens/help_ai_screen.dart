import 'package:flutter/material.dart';

class HelpAiScreen extends StatelessWidget {
  const HelpAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const topics = <(IconData, String, String)>[
      (Icons.point_of_sale_outlined, 'Billing & KOT', 'Create an order, send its KOT to the kitchen, serve it and print the final bill.'),
      (Icons.inventory_2_outlined, 'Inventory', 'Manage products, stock, purchases, vendors and kitchen ingredients.'),
      (Icons.people_alt_outlined, 'CRM & Discounts', 'Maintain customer records and create restaurant discounts.'),
      (Icons.verified_user_outlined, 'PRA & Branches', 'Configure fiscal settings and manage restaurant locations.'),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Help & AI Assistant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Quick guidance for the complete Tycoon POS workflow.', style: TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 22),
          Expanded(child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 150, crossAxisSpacing: 14, mainAxisSpacing: 14),
            itemCount: topics.length,
            itemBuilder: (_, index) {
              final topic = topics[index];
              return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(topic.$1, color: const Color(0xFF6C4CF1)),
                const SizedBox(height: 12),
                Text(topic.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(topic.$3, style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085), height: 1.35)),
              ])));
            },
          )),
        ]),
      ),
    );
  }
}
