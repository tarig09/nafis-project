class AppSession {
  static Map<String, dynamic>? me;
  static bool get isClient => me?['role'] == 'client';
  static bool get isFreelancer => me?['role'] == 'freelancer';
}
