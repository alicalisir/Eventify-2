/// All application strings
abstract final class AppStrings {
  static const String appName = 'ContextAI';

  // Login
  static const String welcomeBack = 'Welcome Back';
  static const String signIn = 'Sign In';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String createAccount = 'Create an Account';
  static const String invalidCredentials =
      'Invalid credentials. Please try again.';

  // Register
  static const String createAccountTitle = 'Create Account';
  static const String startJourney = 'Start your personalized journey';
  static const String fullName = 'Full Name';
  static const String confirmPassword = 'Confirm Password';
  static const String signUp = 'Sign Up';
  static const String agreeToTerms =
      'I agree to the Terms of Service and Privacy Policy';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String emailInUse = 'This email is already in use';
  static const String passwordRequirements =
      'At least 8 characters with letters and numbers';

  // Onboarding
  static const String onboardingTitle1 = 'AI That Understands Your Context';
  static const String onboardingDesc1 =
      'Our intelligent system learns from your daily patterns to provide personalized recommendations exactly when you need them.';
  static const String onboardingTitle2 = 'Location-Aware Suggestions';
  static const String onboardingDesc2 =
      'We need your location to suggest nearby activities, events, and places that match your current context.';
  static const String onboardingTitle3 = 'Timely Interventions';
  static const String onboardingDesc3 =
      'Allow notifications so we can proactively suggest activities when the moment is right.';
  static const String allowAccess = 'Allow Access';
  static const String skip = 'Skip';
  static const String next = 'Next';
  static const String getStarted = 'Get Started';
  static const String permissionRequired = 'Permission Required';
  static const String permissionDeniedMessage =
      'This feature requires the permission to work properly. You can enable it in settings.';
  static const String openSettings = 'Open Settings';

  // Dashboard
  static const String home = 'Home';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String logOut = 'Log Out';
  static const String goodMorning = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening = 'Good evening';
  static const String refreshContext = 'Refresh Context';
  static const String allCaughtUp = "You're all caught up!";
  static const String enjoyActivity =
      'Enjoy your current activity. We\'ll notify you when something comes up.';

  // Suggestion Detail
  static const String acceptAndGo = 'Accept & Go';
  static const String addToCalendar = 'Add to Calendar';
  static const String dismiss = 'Dismiss';
  static const String whyThisSuggestion = 'Why this suggestion?';
  static const String estimatedTime = 'Est. time';
  static const String distance = 'Distance';
  static const String addedToCalendar = 'Successfully added to calendar!';

  // Profile
  static const String myPersona = 'My Persona';
  static const String dataControls = 'Data Controls';
  static const String pauseTracking = 'Pause background tracking';
  static const String for24Hours = 'for 24 hours';
  static const String locationTracking = 'Location Tracking';
  static const String activityRecognition = 'Activity Recognition';
  static const String notifications = 'Notifications';
  static const String privacyPolicy = 'Privacy Policy';
  static const String deleteMyData = 'Delete My Data';
  static const String confirmLogout = 'Are you sure you want to log out?';
  static const String cancel = 'Cancel';

  // Error States
  static const String somethingWentWrong = 'Something went wrong';
  static const String tryAgain = 'Try Again';
  static const String noInternet = 'Lost in the void';
  static const String noInternetDesc =
      'It seems you\'re offline. Check your connection and try again.';
  static const String locationDisabled = 'We can\'t find you';
  static const String locationDisabledDesc =
      'Location services are disabled. Enable them to get personalized suggestions.';
  static const String checkSettings = 'Check Settings';
}
