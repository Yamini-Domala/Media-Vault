import 'package:flutter/material.dart';
// ignore: camel_case_types
class squareTile extends StatelessWidget{
  // ignore: non_constant_identifier_names
  final String Imagepath;
  // ignore: non_constant_identifier_names
  const squareTile ({super.key, required this.Imagepath,});
  @override
  Widget build(BuildContext context){
    return Container(
padding: const EdgeInsets.all(10.0),
decoration: BoxDecoration(border: Border.all(color: Colors.black38)),
child: Image.asset(
  Imagepath,
  height: 40,
),
    );
  }
  
}