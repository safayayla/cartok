import 'package:share_plus/share_plus.dart';

/// Shares plain descriptive text via the native OS share sheet.
///
/// Deliberately does NOT include a deep link — this app has no configured
/// Universal Links (iOS) / App Links (Android) or web-fallback domain yet,
/// so fabricating a `https://cartok.app/...` URL here would share a link
/// that goes nowhere. Once that infrastructure exists, extend [ShareParams]
/// with a `uri:` alongside the text rather than replacing this function's
/// call sites.
Future<void> shareText({required String text, String? subject}) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
