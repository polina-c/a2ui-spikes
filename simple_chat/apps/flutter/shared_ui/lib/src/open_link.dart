import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final Logger _logger = Logger('openLink');

/// Opens [href] with the platform's default handler.
///
/// A link that cannot be parsed or opened is logged and dropped: tapping a
/// broken link should do nothing, not tear down the widget it sits in.
Future<void> openLink(String? href) async {
  if (href == null || href.isEmpty) return;

  final Uri? url = Uri.tryParse(href);
  if (url == null) {
    _logger.warning('Ignoring a markdown link that is not a URL: $href');
    return;
  }

  try {
    if (!await launchUrl(url)) {
      _logger.warning('Could not open $url.');
    }
  } catch (exception, stackTrace) {
    _logger.warning('Could not open $url.', exception, stackTrace);
  }
}
