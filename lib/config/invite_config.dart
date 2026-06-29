/// Central place for the friend-invite copy and link.
///
/// For now the "MyProxi" link points to the marketing site. Once the app is
/// published, switch [inviteUrl] to the store link (a smart link that resolves
/// to the App Store / Play Store, or platform-specific URLs).
class InviteConfig {
  InviteConfig._();

  /// Destination for the tappable "MyProxi" link.
  static const String inviteUrl = 'https://myproxi.app/';

  /// The word rendered as a tappable link inside the invite message.
  static const String brandWord = 'MyProxi';

  /// Sentence shown in-app, with [brandWord] rendered as a link.
  static const String invitePrompt = 'Join me on $brandWord so we can discover our next level in life.';

  /// Plain-text invite for the native share sheet. The URL is appended so it
  /// stays tappable in SMS / WhatsApp / email and other share targets.
  static String shareMessage() => '$invitePrompt\n\n$inviteUrl';
}
