import 'package:flutter/material.dart' hide Text;

import '../../l10n/localized_text.dart';
import 'basket_controller.dart';
import 'consumer_data.dart';
import 'widgets/producer_card.dart';
import 'widgets/producer_profile_page.dart';

const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _cream = Color(0xFFFBFAF5);

/// Vertical feed of producer thumbnails — reached from "Discover producer"
/// and "Show all" under Favorite producers on Home.
class ProducerFeedPage extends StatelessWidget {
  const ProducerFeedPage({
    required this.title,
    required this.producers,
    required this.basket,
    required this.onOpenOrders,
    super.key,
  });

  final String title;
  final List<ProducerSummary> producers;
  final BasketController basket;
  final VoidCallback onOpenOrders;

  void _openProfile(BuildContext context, ProducerSummary producer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ProducerProfilePage(
              sales: producer.products,
              basket: basket,
              onOpenOrders: onOpenOrders,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _ink,
      title: Text(title),
    ),
    body:
        producers.isEmpty
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  localizeText(context, 'No producers to show yet.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              itemCount: producers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder:
                  (context, index) => ProducerCard(
                    producer: producers[index],
                    width: double.infinity,
                    onTap: () => _openProfile(context, producers[index]),
                  ),
            ),
  );
}
