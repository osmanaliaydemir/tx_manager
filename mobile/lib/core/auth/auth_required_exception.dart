class AuthRequiredException implements Exception {
  final String message;
  final int? statusCode;

  const AuthRequiredException([
    this.message = 'Oturum süresi doldu. Lütfen tekrar giriş yap.',
    this.statusCode,
  ]);

  @override
  String toString() => message;
}
