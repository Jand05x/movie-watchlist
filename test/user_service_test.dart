import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/models/user_profile.dart';
import 'package:movie_watchlist/services/user_service.dart';

void main() {
  test('username lookup rejects a profile with a different username', () {
    final profile = UserProfile(
      uid: 'uid-1',
      email: '',
      username: 'tester11',
      displayName: 'Tester Eleven',
    );

    expect(UserService.usernameMatchesProfile('tester1', profile), isFalse);
    expect(UserService.usernameMatchesProfile('tester11', profile), isTrue);
    expect(UserService.usernameMatchesProfile('@TESTER11', profile), isTrue);
  });
}
