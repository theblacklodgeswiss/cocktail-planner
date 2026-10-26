import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mine = StorageLocation(id: 'a', name: 'Mine', ownerEmail: 'Me@X.de');
  const other = StorageLocation(id: 'b', name: 'Other', ownerEmail: 'o@x.de');
  const shared = StorageLocation(id: 'c', name: 'Shared');

  test('pickOwn finds the location of the email', () {
    expect(pickOwn([other, shared, mine], 'Me@X.de'), mine);
  });

  test('pickOwn returns null without match', () {
    expect(pickOwn([other, shared], 'me@x.de'), isNull);
  });

  test('pickOwn ignores email case', () {
    expect(pickOwn([mine], 'me@x.DE'), mine);
  });
}
