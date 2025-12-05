import 'package:flutter/material.dart';
import 'package:lifelens/SignupLogin.dart';
import 'package:lifelens/StartScreen.dart';
import 'package:lifelens/ForgotPassword.dart'; 
import 'package:lifelens/HomeScreen.dart'; 

// Define an enum for different screens
enum AppScreens {
  start,
  signupLogin,
  forgotPassword,
  home,      
}

class LifeLens extends StatefulWidget {
  const LifeLens({super.key});

  @override
  State<LifeLens> createState() => _LifeLensState();
}

class _LifeLensState extends State<LifeLens> {
  AppScreens currentScreen = AppScreens.start;

  // Navigation methods that change currentScreen, add more navigations with same format
  void goToStart() {
    setState(() {
      currentScreen = AppScreens.start;
    });
  }
  
  void goToSignupLogin() {
    setState(() {
      currentScreen = AppScreens.signupLogin;
    });
  }
  
  void goToForgotPassword() { // Fixed method name
    setState(() {
      currentScreen = AppScreens.forgotPassword;
    });
  }

  void goToHome() {
    setState(() {
      currentScreen = AppScreens.home;
    });
  }

  // Getter method that returns the current screen widget, also add by same way
  Widget get activeScreen {
    switch (currentScreen) {
      case AppScreens.start:
        return StartScreen(
          onLoginPressed: goToSignupLogin,
          onForgotPressed: goToForgotPassword, 
        );
      case AppScreens.signupLogin:
        return SignupLogin(
          onSignupSuccess: goToSignupLogin,
          onForgotPressed: goToForgotPassword, 
          onLoginSuccess: goToHome,
        );
      case AppScreens.forgotPassword: 
        return ForgotPassword(
          onBackPressed: goToSignupLogin, 
          onSuccess: goToSignupLogin, 
        );
      case AppScreens.home: 
        // return HomeScreen(
        //   onLogoutPressed: goToStart,
        // TODO: Handle this case.
        throw UnimplementedError(
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: activeScreen,
    );
  }
}