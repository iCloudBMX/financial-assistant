import 'package:flutter/material.dart';
import 'onboarding_controller.dart';

abstract class OnboardingStep {
  String get id;
  String get title;
  Widget build(BuildContext context, OnboardingController controller);
}
