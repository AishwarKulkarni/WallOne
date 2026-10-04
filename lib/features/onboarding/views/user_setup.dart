import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:wallone/features/ads/widgets/intertitial_ad_widget.dart';
import 'package:wallone/features/ads/ad_manager.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:wallone/features/settings/providers/userprofile_provider.dart';

class UserSetupPage extends StatefulWidget {
  const UserSetupPage({super.key});

  @override
  State<UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<UserSetupPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _name = TextEditingController();
  File? _coverImage;
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;
  bool _isSignIn = true;
  bool _showProfileSetup = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showAdAndGoHome() {
    final isPremium = context.read<UserProfileProvider>().isPremium;

    // Skip ads for premium users
    if (isPremium) {
      _goToHome();
      return;
    }

    // ✅ Use the centralized manager instead of local state
    if (InterstitialAdManager.isAvailable) {
      InterstitialAdManager.show();
      // Set callback to navigate after ad
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => _goToHome(),
        onAdFailedToShowFullScreenContent: (ad, error) => _goToHome(),
      );
    } else {
      // No ad available, go directly home
      _goToHome();
    }
  }

  void _goToHome() {
    context.go('/layout');
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    if (_password.text != _confirmPassword.text) {
      snack("Passwords do not match");
      return;
    }

    try {
      setState(() => isLoading = true);
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set({
        "email": _email.text.trim(),
        "createdAt": DateTime.now(),
      });

      // Show profile setup after signup
      setState(() => _showProfileSetup = true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        snack('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        snack('An account already exists for that email.');
      } else if (e.code == 'invalid-email') {
        snack('Invalid email address.');
      } else {
        snack(e.message ?? "Registration failed");
      }
    } catch (e) {
      snack("An unexpected error occurred");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signIn() async {
    try {
      setState(() => isLoading = true);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      // After sign-in, try to load profile from Firestore into provider
      final uid = credential.user?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!mounted) return;

        if (doc.exists) {
          final data = doc.data();
          final name = data?['name'] as String?;

          // Update provider (and SharedPreferences via provider methods)
          if (name != null && name.isNotEmpty) {
            await context.read<UserProfileProvider>().setName(name);
          }
        }
      }

      // Go to the main app
      _showAdAndGoHome();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        snack("Invalid email or password");
      } else if (e.code == 'invalid-email') {
        snack("Invalid email format");
      } else {
        snack(e.message ?? "Authentication failed");
      }
    } catch (e) {
      snack("An unexpected error occurred");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _coverImage = File(picked.path));
      }
    } catch (e) {
      snack("Failed to pick image: $e");
    }
  }

  Future<void> saveProfile() async {
    if (_name.text.trim().isEmpty) {
      snack("Please enter your name");
      return;
    }
    try {
      setState(() => isLoading = true);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": _name.text.trim(),
      });
      if (!mounted) return;

      // Update the in-app provider so UI shows the name/image immediately
      try {
        await context.read<UserProfileProvider>().setName(_name.text.trim());
        if (_coverImage != null) {
          if (!mounted) return;
          // Use the picked file path directly so app can show it immediately
          await context
              .read<UserProfileProvider>()
              .setImagePath(_coverImage!.path);
        }
      } catch (_) {}

      // Mark onboarding as complete in Firestore
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({'hasSeenOnboarding': true}, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error saving onboarding state: $e');
      }

      _showAdAndGoHome();
    } catch (e) {
      snack("An unexpected error occurred while saving profile");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      body: _showProfileSetup ? buildProfileSetup() : buildAuthPage(),
    );
  }

  Widget buildAuthPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            _isSignIn ? "Welcome Back!" : "Create Account",
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _isSignIn ? "Sign in to continue" : "Create an account",
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shadowColor(context).withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _email,
              style: GoogleFonts.outfit(color: budgetTextLight(context)),
              decoration: InputDecoration(
                filled: true,
                fillColor: boxColor(context),
                labelText: "Email Address",
                labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: purpleColors(context), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shadowColor(context).withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _password,
              obscureText: true,
              style: GoogleFonts.outfit(color: budgetTextLight(context)),
              decoration: InputDecoration(
                filled: true,
                fillColor: boxColor(context),
                labelText: "Password",
                labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: purpleColors(context), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (!_isSignIn) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor(context).withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _confirmPassword,
                obscureText: true,
                style: GoogleFonts.outfit(color: budgetTextLight(context)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: boxColor(context),
                  labelText: "Confirm Password",
                  labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: purpleColors(context), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
          if (_isSignIn) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Forgot Password?",
                style: GoogleFonts.outfit(
                  color: purpleColors(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          isLoading
              ? Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(purpleColors(context)),
                  ),
                )
              : Column(
                  children: [
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          primaryColor(context),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      onPressed: _isSignIn ? signIn : signUp,
                      child: Text(
                        _isSignIn ? 'Sign In' : 'Sign Up',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: inversePrimaryColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignIn
                              ? "Don't have an account? "
                              : "Already have an account? ",
                          style: GoogleFonts.outfit(
                            color: primaryColor(context).withValues(alpha: 0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isSignIn = !_isSignIn);
                          },
                          child: Text(
                            _isSignIn ? "Sign Up" : "Sign In",
                            style: GoogleFonts.outfit(
                              color: purpleColors(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget buildProfileSetup() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            "Set Up Profile",
            style: GoogleFonts.outfit(
              color: purpleColors(context),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: pickImage,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: purpleColors(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: purpleColors(context), width: 1),
              ),
              child: _coverImage == null
                  ? Center(
                      child: Icon(
                        Icons.person_2,
                        color: purpleColors(context),
                        size: 30,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_coverImage!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 50),
          TextField(
            controller: _name,
            style: GoogleFonts.outfit(color: primaryColor(context)),
            decoration: InputDecoration(
              labelText: "Enter your name!",
              labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Spacer(),
          isLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(purpleColors(context)),
                )
              : ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      purpleColors(context),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  onPressed: saveProfile,
                  child: Text(
                    'Continue',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: primaryColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
