import 'package:flutter/material.dart';

class OfferModel {
  final String title;
  final String description;
  final String code;
  final String validTill;
  final List<Color> gradientColors;
  final IconData icon;

  const OfferModel({
    required this.title,
    required this.description,
    required this.code,
    required this.validTill,
    required this.gradientColors,
    required this.icon,
  });
}

final List<OfferModel> restaurantOffers = [
  OfferModel(
    title: '50% OFF on Family Pack',
    description: 'Get 50% off on all family pack items',
    code: 'FAMILY50',
    validTill: 'Valid till March 31, 2026',
    gradientColors: [const Color(0xFFFF8C00), const Color(0xFFE8532A)],
    icon: Icons.card_giftcard_rounded,
  ),
  OfferModel(
    title: 'Buy 2 Get 1 Free',
    description: 'On all starters & main course category items',
    code: 'CUBES',
    validTill: 'Valid till March 30, 2026',
    gradientColors: [const Color(0xFF9B59B6), const Color(0xFF6C3483)],
    icon: Icons.card_giftcard_rounded,
  ),
  OfferModel(
    title: 'Free Delivery',
    description: 'On orders above ₹500',
    code: 'FREEDEL',
    validTill: 'Valid till April 5, 2026',
    gradientColors: [const Color(0xFF2ECC71), const Color(0xFF1A8A4A)],
    icon: Icons.card_giftcard_rounded,
  ),
];
