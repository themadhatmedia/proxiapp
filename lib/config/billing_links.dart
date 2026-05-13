/// ## How to verify the app opens (custom schemes often fail in the browser bar)
///
/// **Do not rely on pasting `proxiapp://…` into Safari or Chrome’s address bar** — many builds
/// ignore or search instead of opening the app.
///
/// Reliable checks:
/// - **iOS**: Apple Notes → type or paste `proxiapp://billing/success` → it becomes a tappable
///   link → tap it. Or **Shortcuts** → Open URLs.
/// - **Android**: connect USB and run:
///   `adb shell am start -a android.intent.action.VIEW -d "proxiapp://billing/success" com.app.proxiapp`
/// - **Any**: open an HTML page or backend redirect that uses `<a href="proxiapp://billing/success">`
///   (tap the link, don’t type the URL in the bar).
///
/// Stripe Checkout return: open the app after browser payment.
///
/// ## Give these to your backend developer (Stripe success_url / cancel_url)
///
/// Stripe expects HTTPS URLs in many setups. Typical pattern:
/// 1. `success_url` points to `https://myproxi.app/billing/success?session_id={CHECKOUT_SESSION_ID}`
/// 2. That web page immediately redirects to the app using the **custom scheme** below
///    (meta refresh, `window.location`, or a “Open app” button).
///
/// **Success (opens app; include session id when Stripe substitutes it):**
/// `proxiapp://billing/success?session_id={CHECKOUT_SESSION_ID}`
///
/// **Cancel:**
/// `proxiapp://billing/cancel`
///
/// Exact literals for copy-paste (Stripe replaces `{CHECKOUT_SESSION_ID}` when configured):
/// - Success template: `proxiapp://billing/success?session_id={CHECKOUT_SESSION_ID}`
/// - Cancel: `proxiapp://billing/cancel`
class BillingLinks {
  BillingLinks._();

  static const String scheme = 'proxiapp';
  static const String host = 'billing';

  /// Example success URI after payment (session id optional until Stripe fills it).
  static Uri successUri({String? sessionId}) {
    if (sessionId != null && sessionId.isNotEmpty) {
      return Uri(scheme: scheme, host: host, path: '/success', queryParameters: {'session_id': sessionId});
    }
    return Uri(scheme: scheme, host: host, path: '/success');
  }

  static Uri cancelUri() => Uri(scheme: scheme, host: host, path: '/cancel');

  /// Backend / Stripe Dashboard documentation strings.
  static const String stripeSuccessUrlTemplate = 'proxiapp://billing/success?session_id={CHECKOUT_SESSION_ID}';
  static const String stripeCancelUrl = 'proxiapp://billing/cancel';
}
