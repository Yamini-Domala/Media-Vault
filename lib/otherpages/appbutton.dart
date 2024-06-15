import 'package:flutter/material.dart';

class Myappbutton extends StatelessWidget{
const Myappbutton({super.key, required this.onTap, });
final void Function()? onTap;
 
@override
Widget build(BuildContext context){
return GestureDetector(
  onTap: onTap,
  child: Container(
    decoration: BoxDecoration(color: const Color.fromARGB(255, 47, 47, 47),
    borderRadius: BorderRadius.circular(10),
    ),
  
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 30),
      child: const Center(child: Text(
        'LogIn',
      style:TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 20,
        color: Colors.white),
        
      ),
      
      ),
    
  
  ),
);
}


}