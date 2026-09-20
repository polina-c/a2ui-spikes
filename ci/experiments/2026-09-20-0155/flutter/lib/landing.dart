import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the landing page of a machine the assistant recommended.
///
/// genui ships `openUrl`, which takes the address from the model. This takes
/// the name of the machine instead and looks the address up, because a URL a
/// language model repeats back can come back a path segment short - which is
/// exactly what happened on the React arm of this experiment.
class OpenLandingPage extends SynchronousClientFunction {
  const OpenLandingPage(this.urls);

  final Map<String, String> urls;

  @override
  String get name => 'openLandingPage';

  @override
  String get description =>
      'Opens the landing page of one machine. Takes "model", the name of the '
      'machine in lower case, one of: mini, slim, classic, family, silent, eco. '
      'The app holds the addresses, so do not pass a URL.';

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Schema get argumentSchema =>
      S.object(properties: {'model': A2uiSchemas.stringReference()});

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    final url = urls[(args['model'] as String? ?? '').toLowerCase()];
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    launchUrl(uri, webOnlyWindowName: '_blank');
    return true;
  }
}
