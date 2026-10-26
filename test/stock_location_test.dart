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

  group('findClaimableLocation', () {
    const biri = StorageLocation(id: 'x', name: 'Biri');
    const biriEmpty = StorageLocation(id: 'y', name: 'Biri', ownerEmail: '');
    const biriOwned = StorageLocation(
      id: 'z',
      name: 'Biri',
      ownerEmail: 'b@x.de',
    );

    test('matches an ownerless location by name, ignoring case and spaces', () {
      expect(findClaimableLocation([other, biri], ' biri '), biri);
      expect(findClaimableLocation([biriEmpty], 'BIRI'), biriEmpty);
    });

    test('ignores owned locations and other names', () {
      expect(findClaimableLocation([biriOwned, other], 'Biri'), isNull);
      expect(findClaimableLocation([biri], 'Tuji'), isNull);
      expect(findClaimableLocation([biri], '  '), isNull);
    });
  });

  group('owner email helpers', () {
    test('normalise to lower case and trim', () {
      expect(normalizeOwnerEmail('  Me@X.DE '), 'me@x.de');
    });

    test('valid when empty or containing @', () {
      expect(isValidOwnerEmail(''), isTrue);
      expect(isValidOwnerEmail('a@b.de'), isTrue);
      expect(isValidOwnerEmail('nope'), isFalse);
    });
  });
}
