import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/logger.dart';

class IbanResult {
  final bool valid;
  final String iban;
  final String? bankCode;
  final String? name;
  final String? bic;

  IbanResult(
      {required this.valid,
      required this.iban,
      this.bankCode,
      this.name,
      this.bic});
  @override
  String toString() {
    return '{Valid: $valid, Iban: $iban, BankCode: $bankCode, Name: $name, Bic: $bic}';
  }
}

Future<IbanResult> validateIban(String iban) async {
  final response = await http.get(Uri.parse(
      'https://openiban.com/validate/$iban?validateBankCode=true&getBIC=true'));
  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body);
    consLog.i(data.toString());
    return IbanResult(
        valid: data['valid'],
        iban: data['iban'],
        bankCode: data['bankData']['bankCode'],
        name: data['bankData']['name'],
        bic: data['bankData']['bic']);
  } else {
    // Handle error
    return IbanResult(valid: false, iban: iban);
  }
}
