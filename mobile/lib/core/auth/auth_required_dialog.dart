import 'package:flutter/material.dart';

Future<bool> showAuthRequiredDialog(
  BuildContext context, {
  String title = 'Giriş gerekli',
  String message =
      'Oturum süresi doldu. Devam etmek için tekrar giriş yapmalısın.',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF252A34),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.grey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Giriş Yap'),
        ),
      ],
    ),
  );
  return res == true;
}
