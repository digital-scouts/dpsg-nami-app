import 'package:flutter/material.dart';
import 'package:nami/utilities/pdf/readPDF.dart';

class Profil extends StatefulWidget {
  const Profil({Key? key}) : super(key: key);

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Profil')),
      ),
      body: Center(
        child: readPdf(context),
      ),
    );
  }
}
