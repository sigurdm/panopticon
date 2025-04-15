import 'dart:convert';

import 'package:http/http.dart';

Future<List<String>> allPackageNames(Client client) async {
  final nextUrl = Uri.https('pub.dev', 'api/packages', {'compact': '1'});
  final response = await client.get(nextUrl);
  final result = json.decode(response.body);
  return List<String>.from((result as Map)['packages'] as List);
}

Future<Object?> versionListing(Client client, String packageName) async {
  final url = Uri.https('pub.dev', 'api/packages/$packageName');
  return jsonDecode(await client.read(url));
}

Future<Object?> scoreListing(Client client, String packageName) async {
  final url = Uri.https('pub.dev', 'api/packages/$packageName/score');
  return jsonDecode(await client.read(url));
}

Future<T> withClient<T>(Future<T> fn(Client client)) async {
  final client = Client();
  try {
    return await fn(client);
  } finally {
    client.close();
  }
}
