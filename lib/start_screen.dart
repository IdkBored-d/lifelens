import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({
    super.key,
    required this.onLoginPressed,
    required this.onForgotPressed,
  });

  final void Function() onLoginPressed;
  final void Function() onForgotPressed;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "LifeLens",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue, 
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextButton(
                onPressed: onLoginPressed, 
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Login/Register",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ]
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80.0), 
            child: Center(
              child: Text(
                "Your Journal for Better Mental Health.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1, 
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                    ),
                    child: Center(
                      child: Text(
                        "",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } 
}