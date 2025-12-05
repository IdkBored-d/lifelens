import 'package:flutter/material.dart';

class SignupLogin extends StatefulWidget {
  const SignupLogin({
    super.key,
    required this.onLoginSuccess,
    required this.onSignupSuccess,
    required this.onForgotPressed,
  });
  
  final void Function() onLoginSuccess;
  final void Function() onSignupSuccess;
  final void Function() onForgotPressed;
  
  @override
  State<SignupLogin> createState() => _SignupLoginState();
}

class _SignupLoginState extends State<SignupLogin> {
  bool isLogin = true; 
  bool rememberMe = false;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (isLogin) {
        //add api call
        print('Logging in with: ${_usernameController.text}');
        // After successful login API call
        widget.onLoginSuccess(); 
      } else {
        //add api call
        print('Signing up with: ${_usernameController.text}');
        // After successful signup API call
        widget.onSignupSuccess(); 
      }
    }
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 80),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isLogin ? "Welcome Back!" : "Create Account",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              isLogin 
                ? "Sign in to continue your mental health journey"
                : "Join LifeLens for better mental well-being",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 40),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _usernameController,
                      label: "Username",
                      hint: "Enter your username",
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      hint: "Enter your password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (!isLogin)
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: "Confirm Password",
                        hint: "Re-enter your password",
                        icon: Icons.lock_reset_outlined,
                        isPassword: true,
                        validator: (value) {
                          if (!isLogin && value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          isLogin ? "Sign In" : "Create Account",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          if (isLogin)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          rememberMe = value ?? false;
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Text(
                                      "Remember me",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),

                                TextButton(
                                  onPressed: widget.onForgotPressed, 
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          
                          if (isLogin) const SizedBox(height: 30),
                          
                          Container(
                            height: 1,
                            color: Colors.grey[300],
                          ),
                          
                          const SizedBox(height: 30),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin ? "Don't have an account? " : "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                              GestureDetector(
                                onTap: _toggleMode,
                                child: Text(
                                  isLogin ? "Sign Up" : "Sign In",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),

                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    bool obscureText = isPassword;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(icon, color: Colors.grey[600]),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
              ),
              validator: validator,
            ),
          ],
        );
      },
    );
  }
}