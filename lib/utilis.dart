import"package:firebase_auth/firebase_auth.dart";
Future<void>signInUserAnon() async{
  try{
 final userCredential=await FirebaseAuth.instance.signInAnonymously();
 print("signed with temp acct. UID: ${userCredential.user?.uid}");
  }catch(e){
    print(e);
  }
}
