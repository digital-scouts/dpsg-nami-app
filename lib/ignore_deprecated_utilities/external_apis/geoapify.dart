import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wiredash/wiredash.dart';

Future<bool> validateGermanAdress(
  String housenumber,
  String street,
  String postcode,
  String city,
) async {
  String apiKey = startUp();
  Wiredash.trackEvent('Geoapify validate adress');

  final response = await http.get(
    Uri.parse(
      'https://api.geoapify.com/v1/geocode/search?housenumber=$housenumber&street=$street&postcode=$postcode&city=$city&country=Germany&format=json&apiKey=$apiKey',
    ),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to load address');
  }
  var data = jsonDecode(response.body);
  if (data['results'].isEmpty) {
    return false;
  }

  const acceptLevel = 0.95;
  const declineLevel = 0.5;
  var address = data['results'][0];
  if (address['rank']['confidence'] >= acceptLevel) {
    return true;
  } else if (address['rank']['confidence'] < declineLevel) {
    return false;
  } else {
    if (address['rank']['confidence_street_level'] >= acceptLevel) {
      return false;
    } else if (address['rank']['confidence_city_level'] >= acceptLevel) {
      return false;
    } else {
      return false;
    }
  }
}

Future<List<GeoapifyAdress>> autocompleteGermanAdress(String text) async {
  String apiKey = startUp();
  Wiredash.trackEvent('Geoapify autocomplete adress');

  final response = await http.get(
    Uri.parse(
      'https://api.geoapify.com/v1/geocode/autocomplete?text=$text&lang=de&limit=3&filter=countrycode:de&format=json&apiKey=$apiKey',
    ),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to load address');
  }
  var data = jsonDecode(response.body);
  List<GeoapifyAdress> addresses = [];
  for (var address in data['results']) {
    addresses.add(GeoapifyAdress.fromJson(address));
  }
  return addresses;
}

String startUp() {
  String? apiKey = dotenv.env['GEOAPIFY_KEY'];
  if (apiKey == null) {
    throw Exception('No API key found for Geoapify');
  }
  return apiKey;
}

class GeoapifyAdress {
  String? country;
  String? countryCode;
  String? state;
  String? city;
  String? postcode;
  String? street;
  String formatted;
  String? housenumber;

  GeoapifyAdress({
    this.country,
    this.countryCode,
    this.state,
    this.city,
    this.postcode,
    this.street,
    required this.formatted,
    this.housenumber,
  });

  factory GeoapifyAdress.fromJson(Map<String, dynamic> json) {
    return GeoapifyAdress(
      country: json['country'],
      countryCode: json['country_code'],
      state: json['state'],
      city: json['city'],
      postcode: json['postcode'],
      street: json['street'],
      formatted: json['formatted'],
      housenumber: json['housenumber'],
    );
  }
}
