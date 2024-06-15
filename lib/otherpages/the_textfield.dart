import 'package:flutter/material.dart';
class MyTextfeild extends StatelessWidget{
  // ignore: prefer_typing_uninitialized_variables
  final controller;
  final String hintText;
  final bool obsecureText;
const MyTextfeild({super.key,
required this.controller,
required this.hintText,
required this.obsecureText,

});
@override
Widget build(BuildContext context){

  
  return  Padding(padding:const EdgeInsets.symmetric(horizontal:30.0),
   child: TextField(
            controller:controller ,
            obscureText:obsecureText ,
              decoration: InputDecoration(
              enabledBorder: const OutlineInputBorder(
                borderSide:BorderSide(color: Color.fromARGB(255, 251, 167, 255)) 
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide:BorderSide(color: Color.fromARGB(0, 240, 160, 240))
              ),
              fillColor: const Color.fromARGB(255, 236, 224, 255),
              filled: true,
              hintText: hintText,
            ),
          ),
 );
  
}
  }