import 'package:shared_preferences/shared_preferences.dart';

import 'streak_service.dart';

enum MiniMeItemType { hair, shirt, bodyScale }

class MiniMeShopItem {
  const MiniMeShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    this.assetPath,
    this.bodyScale,
  });

  final String id;
  final String name;
  final String description;
  final int cost;
  final MiniMeItemType type;
  final String? assetPath;
  final double? bodyScale;
}

class MiniMeShopState {
  const MiniMeShopState({
    required this.coins,
    required this.unlockedIds,
    required this.items,
    required this.lastReward,
  });

  final int coins;
  final Set<String> unlockedIds;
  final List<MiniMeShopItem> items;
  final DailyRewardResult lastReward;
}

class DailyRewardResult {
  const DailyRewardResult({
    required this.rewarded,
    required this.amount,
    required this.message,
  });

  final bool rewarded;
  final int amount;
  final String message;
}

class MiniMeShopService {
  MiniMeShopService._();

  static final MiniMeShopService instance = MiniMeShopService._();

  static const String _coinsKey = 'minimeShop.coins';
  static const String _unlockedKey = 'minimeShop.unlockedIds';
  static const String _lastRewardDayKey = 'minimeShop.lastRewardDay';

  static const List<MiniMeShopItem> _catalog = [
    MiniMeShopItem(
      id: 'hair.classic',
      name: 'Classic Hair',
      description: 'A clean default hair style.',
      cost: 18,
      type: MiniMeItemType.hair,
      assetPath: 'lib/assets/minime/hair/hair.glb',
    ),
    MiniMeShopItem(
      id: 'hair.athlete',
      name: 'Athlete Hair',
      description: 'Sporty silhouette for consistency legends.',
      cost: 30,
      type: MiniMeItemType.hair,
      assetPath: 'lib/assets/minime/hair/hair_male.glb',
    ),
    MiniMeShopItem(
      id: 'shirt.tie',
      name: 'Neck Tie Shirt',
      description: 'Formal look for high-focus days.',
      cost: 24,
      type: MiniMeItemType.shirt,
      assetPath: 'lib/assets/minime/shirts/neck_tie.glb',
    ),
    MiniMeShopItem(
      id: 'stance.power',
      name: 'Power Stance',
      description: 'A wider body stance preset.',
      cost: 15,
      type: MiniMeItemType.bodyScale,
      bodyScale: 1.12,
    ),
    MiniMeShopItem(
      id: 'stance.focus',
      name: 'Focus Stance',
      description: 'A leaner profile preset.',
      cost: 15,
      type: MiniMeItemType.bodyScale,
      bodyScale: 0.9,
    ),
  ];

  Future<MiniMeShopState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final coins = prefs.getInt(_coinsKey) ?? 0;
    final unlocked = (prefs.getStringList(_unlockedKey) ?? const <String>[])
        .toSet();
    return MiniMeShopState(
      coins: coins,
      unlockedIds: unlocked,
      items: _catalog,
      lastReward: const DailyRewardResult(
        rewarded: false,
        amount: 0,
        message: '',
      ),
    );
  }

  Future<MiniMeShopState> grantDailyRewards({
    required StreakSnapshot streak,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DateTime.now());
    final lastRewardDay = prefs.getString(_lastRewardDayKey);

    final currentCoins = prefs.getInt(_coinsKey) ?? 0;
    final unlocked = (prefs.getStringList(_unlockedKey) ?? const <String>[])
        .toSet();

    if (lastRewardDay == todayKey) {
      return MiniMeShopState(
        coins: currentCoins,
        unlockedIds: unlocked,
        items: _catalog,
        lastReward: const DailyRewardResult(
          rewarded: false,
          amount: 0,
          message: 'Daily reward already claimed today.',
        ),
      );
    }

    if (!streak.loggedToday) {
      return MiniMeShopState(
        coins: currentCoins,
        unlockedIds: unlocked,
        items: _catalog,
        lastReward: const DailyRewardResult(
          rewarded: false,
          amount: 0,
          message: 'Log at least one tracker today to earn coins.',
        ),
      );
    }

    const reward = 2;

    final nextCoins = currentCoins + reward;
    await prefs.setInt(_coinsKey, nextCoins);
    await prefs.setString(_lastRewardDayKey, todayKey);

    return MiniMeShopState(
      coins: nextCoins,
      unlockedIds: unlocked,
      items: _catalog,
      lastReward: DailyRewardResult(
        rewarded: true,
        amount: reward,
        message: 'Streak reward claimed (2 coins).',
      ),
    );
  }

  Future<MiniMeShopState> unlockItem({required String itemId}) async {
    final prefs = await SharedPreferences.getInstance();
    final item = _catalog.firstWhere((e) => e.id == itemId);

    final unlocked = (prefs.getStringList(_unlockedKey) ?? const <String>[])
        .toSet();
    final coins = prefs.getInt(_coinsKey) ?? 0;

    if (unlocked.contains(itemId) || coins < item.cost) {
      return MiniMeShopState(
        coins: coins,
        unlockedIds: unlocked,
        items: _catalog,
        lastReward: const DailyRewardResult(
          rewarded: false,
          amount: 0,
          message: '',
        ),
      );
    }

    unlocked.add(itemId);
    final nextCoins = coins - item.cost;

    await prefs.setInt(_coinsKey, nextCoins);
    await prefs.setStringList(_unlockedKey, unlocked.toList());

    return MiniMeShopState(
      coins: nextCoins,
      unlockedIds: unlocked,
      items: _catalog,
      lastReward: const DailyRewardResult(
        rewarded: false,
        amount: 0,
        message: '',
      ),
    );
  }

  String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }
}
