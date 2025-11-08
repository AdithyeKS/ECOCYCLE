import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import 'package:ecocycle_1/core/supabase_config.dart';import 'package:ecocycle_1/core/supabase_config.dart';

import 'package:ecocycle_1/screens/forgot_password_screen.dart';import 'package:ecocycle_1/screens/forgot_password_screen.dart';

import 'package:ecocycle_1/screens/home_shell.dart';import 'package:ecocycle_1/screens/home_shell.dart';

import 'package:ecocycle_1/screens/signup_screen.dart';import 'package:ecocycle_1/screens/signup_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';import 'package:flutter_animate/flutter_animate.dart';

import 'package:easy_localization/easy_localization.dart';import 'package:easy_localization/easy_localization.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
class LoginScreen extends StatefulWidget {

  final VoidCallback? onThemeToggle;  final VoidCallback? onThemeToggle;

  const LoginScreen({super.key, this.onThemeToggle});  const LoginScreen({super.key, this.onThemeToggle});



  @override  @override

  State<LoginScreen> createState() => _LoginScreenState();  State<LoginScreen> createState() => _LoginScreenState();

}}



class _LoginScreenState extends State<LoginScreen> {class _LoginScreenState extends State<LoginScreen> {

    setState(() {        password: _password.text,
