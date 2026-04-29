import 'package:jaspr/server.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> args) async {
  final handler = serveApp((_, render) async {
    return render(
      Document(
        title: 'Pricing Platform',
        body: div([text('Jaspr SSR scaffold running')]),
      ),
    );
  });
  final server = await io.serve(handler, '0.0.0.0', 8081);
  // ignore: avoid_print
  print('Jaspr server running on http://${server.address.host}:${server.port}');
}

