import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appw_models;
import 'package:logger/logger.dart';

final logger = Logger();

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  final Client client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1') // Remplace par ton endpoint
    ..setProject('686ac0840038d075de43'); // Remplace par ton projectId

  late final Account account = Account(client);
  late final Databases databases = Databases(client);
  late final Storage storage = Storage(client);
  late final Realtime realtime = Realtime(client);

  // Auth: Email/password
  Future<appw_models.User?> signUpWithEmail(String email, String password, {String? name}) async {
    final user = await account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    return user;
  }

  Future<appw_models.Session?> loginWithEmail(String email, String password) async {
    final session = await account.createEmailSession(email: email, password: password);
    return session;
  }

  // Auth: OAuth (Google, Apple)
  Future<void> loginWithOAuth(String provider) async {
    // provider: 'google' ou 'apple'
    await account.createOAuth2Session(provider: provider);
  }

  Future<void> logout() async {
    await account.deleteSession(sessionId: 'current');
  }

  Future<appw_models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (_) {
      return null;
    }
  }
} 