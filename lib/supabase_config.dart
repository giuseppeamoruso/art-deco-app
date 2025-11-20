import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://fykszvedjcgurryynhha.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5a3N6dmVkamNndXJyeXluaGhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxODc1ODksImV4cCI6MjA3MTc2MzU4OX0.H_HOV90GkbdZ_0Ue5ml781Qm1q8N6eukcDgXHAqE0VY';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}
