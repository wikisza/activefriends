import 'package:activefriends/src/app/active_friends_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bottom tabs include map, chat, and profile', (WidgetTester tester) async {
    await tester.pumpWidget(const ActiveFriendsApp());
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Szukaj aktywnosci w Bydgoszczy'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Czat'), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Czat'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Brak rozmów'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Profil'), findsWidgets);
  });
}
