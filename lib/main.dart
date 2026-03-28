import 'package:activefriends/src/app/active_friends_app.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kalaofclgpuogyebqzgt.supabase.co',
    anonKey: 'sb_publishable_4R3GrrJTb-B5NSx3AOB15A_64iHflgT',
  );

  await initializeDateFormatting('pl_PL', null);

  runApp(const ActiveFriendsApp());
}
