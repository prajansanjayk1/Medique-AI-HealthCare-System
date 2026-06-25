import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _professionController = TextEditingController();
  
  String? _selectedGender;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.registerPatient(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: _ageController.text.trim(),
        address: _addressController.text.trim(),
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        gender: _selectedGender,
        profession: _professionController.text.trim().isNotEmpty ? _professionController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully! Please log in.")),
        );
        Navigator.of(context).pop(); // Back to login screen
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll(RegExp(r'\[.*\]'), '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientDecoration,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF475569), size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.03),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        "Join the smart clinic queue instantly",
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Registration Form Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: AppTheme.glassCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Full Name *",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your name.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Email Address *",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || !AppUtils.isValidEmail(value.trim())) {
                                return "Please enter a valid email address.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Phone Number *",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || !AppUtils.isValidPhone(value.trim())) {
                                return "Please enter a valid phone number.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Age & Gender Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: "Age *",
                                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                    prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF64748B)),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.015),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Enter age";
                                    }
                                    if (int.tryParse(value.trim()) == null) {
                                      return "Invalid";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: "Gender",
                                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                    prefixIcon: const Icon(Icons.wc_outlined, color: Color(0xFF64748B)),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.015),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                    ),
                                  ),
                                  items: ["Male", "Female", "Other", "Prefer not to say"]
                                      .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(color: Color(0xFF1E293B)))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedGender = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Address
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Home Address *",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                    return "Please enter your address.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // DOB Date Picker
                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Date of Birth",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              hintText: "Select Date",
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Profession
                          TextFormField(
                            controller: _professionController,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Profession",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                            decoration: InputDecoration(
                              labelText: "Password *",
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF64748B)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length < 6) {
                                return "Password must be at least 6 characters.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Error Message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Submit Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Back Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already have an account? ",
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Text(
                                  "Log In",
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
