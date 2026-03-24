import 'package:shelf/shelf.dart';

Middleware jsonMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      if (request.url.path.startsWith('api/')) {
        return response.change(headers: {
          'Content-Type': 'application/json',
        });
      }
      return response;
    };
  };
}
