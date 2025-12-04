import 'dart:convert';
import 'package:http/http.dart' as http;

class PlzResult {
  final String city;
  final String state;
  final String country;

  PlzResult({required this.city, required this.state, required this.country});
  @override
  String toString() {
    return '{City: $city, State: $state, Country: $country}';
  }
}

Future<List<PlzResult>> fetchCityAndState(String plz) async {
  final response = await http.get(
    Uri.parse('https://openplzapi.org/de/Localities?postalCode=$plz'),
  );
  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    List<PlzResult> plzData = [];
    //{"postalCode":"25436","name":"Groß Nordende","municipality":{"key":"01056016","name":"Groß Nordende","type":"Kreisangehörige_Gemeinde"},"district":{"key":"01056","name":"Pinneberg","type":"Kreis"},"federalState":{"key":"01","name":"Schleswig-Holstein"}}
    data.forEach(
      (place) => plzData.add(
        PlzResult(
          city: place['name'],
          state: place['federalState']['name'],
          country: 'Deutschland',
        ),
      ),
    );
    return plzData;
  } else {
    // Handle error
    return List.empty();
  }
}
