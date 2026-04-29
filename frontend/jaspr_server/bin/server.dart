import 'package:jaspr/jaspr.dart';
import 'package:jaspr/server.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> args) async {
  final app = Document(
    title: 'Pricing Platform',
    body: [text('Jaspr SSR scaffold running')],
  );

  final handler = jasprHandler((_) => app);
  final server = await io.serve(handler, '0.0.0.0', 8081);
  // ignore: avoid_print
  print('Jaspr server running on http://${server.address.host}:${server.port}');
}

