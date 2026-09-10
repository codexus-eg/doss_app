// DOSS App Strings v6 — Arabic + English (Ride + Shuttle)

class S {
  final String en;
  final String ar;
  const S(this.en, this.ar);
  String get(bool isArabic) => isArabic ? ar : en;
}

class AppStrings {
  AppStrings._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const welcomeBack    = S('Welcome back',                'مرحباً بك مجدداً');
  static const signInSubtitle = S('Sign in to your DOSS account','سجّل دخول لحسابك في DOSS');
  static const phoneNumber    = S('Phone number',                'رقم الهاتف');
  static const password       = S('Password',                    'كلمة المرور');
  static const signIn         = S('Sign In',                     'تسجيل الدخول');
  static const signUp         = S('Sign Up',                     'إنشاء حساب');
  static const noAccount      = S("Don't have an account? ",     'ليس لديك حساب؟ ');
  static const haveAccount    = S('Already have an account? ',   'لديك حساب بالفعل؟ ');
  static const fullName       = S('Full name',                   'الاسم الكامل');
  static const confirmPw      = S('Confirm password',            'تأكيد كلمة المرور');
  static const createAccount  = S('Create Account',              'إنشاء الحساب');
  static const phoneRequired  = S('Phone is required',           'رقم الهاتف مطلوب');
  static const pwRequired     = S('Password is required',        'كلمة المرور مطلوبة');
  static const nameRequired   = S('Name is required',            'الاسم مطلوب');
  static const pwMismatch     = S('Passwords do not match',      'كلمة المرور غير متطابقة');

  // ── Home ──────────────────────────────────────────────────────────────────
  static const hello          = S('Hello',                       'مرحباً');
  static const whereGoing     = S('Where are you going?',        'إلى أين تريد الذهاب؟');
  static const searchDest     = S('Search destination...',       'ابحث عن وجهتك...');
  static const cashOnly       = S('Cash only',                   'نقدي فقط');

  // ── Vehicle Types ─────────────────────────────────────────────────────────
  static const car            = S('Car',                         'سيارة');
  static const bike           = S('Bike',                        'دراجة');
  static const shuttle        = S('Shuttle',                     'شاتل');
  static const shuttleTagline = S('Fixed routes • Low fares',    'خطوط ثابتة • أسعار منخفضة');
  static const fromPrice      = S('From',                        'من');

  // ── Booking ───────────────────────────────────────────────────────────────
  static const bookRide       = S('Book a Ride',                 'احجز رحلة');
  static const pickupLoc      = S('Pickup location',             'موقع الانطلاق');
  static const whereTo        = S('Where to?',                   'إلى أين؟');
  static const confirmRide    = S('Confirm Ride',                'تأكيد الرحلة');
  static const cashPayment    = S('Cash Payment Only',           'الدفع نقداً فقط');

  // ── Shuttle Booking ───────────────────────────────────────────────────────
  static const bookShuttle       = S('Book Shuttle',             'احجز شاتل');
  static const shuttleTitle      = S('DOSS Shuttle',             'DOSS شاتل');
  static const shuttleSubtitle   = S('Fixed routes at low fares', 'خطوط ثابتة بأسعار منخفضة');
  static const selectRoute       = S('Select Route',             'اختر الخط');
  static const selectStation     = S('Select Station',           'اختر المحطة');
  static const pickupStation     = S('Pickup Station',           'محطة الانطلاق');
  static const dropoffStation    = S('Drop-off Station',         'محطة الوصول');
  static const availableRoutes   = S('Available Routes',         'الخطوط المتاحة');
  static const stationNearYou    = S('Stations near you',        'المحطات القريبة منك');
  static const fixedFare         = S('Fixed Fare',               'سعر ثابت');
  static const routeDetails      = S('Route Details',            'تفاصيل الخط');
  static const shuttleRoute      = S('Shuttle Route',            'خط الشاتل');
  static const distance          = S('Distance',                 'المسافة');
  static const estimatedTime     = S('Estimated Time',           'الوقت التقديري');
  static const confirmShuttle    = S('Confirm Shuttle',          'تأكيد الشاتل');
  static const noRoutesAvailable = S('No routes available in your area',
                                     'لا توجد خطوط متاحة في منطقتك');
  static const shuttleNote       = S('Shuttle picks up multiple passengers on the same route.',
                                     'الشاتل يستقل ركاباً متعددين على نفس الخط.');
  static const governorate       = S('Governorate',              'المحافظة');
  static const filterByGov       = S('Filter by city',           'تصفية حسب المدينة');
  static const allCities         = S('All Cities',               'كل المدن');
  static const cairo             = S('Cairo',                    'القاهرة');
  static const giza              = S('Giza',                     'الجيزة');
  static const alexandria        = S('Alexandria',               'الإسكندرية');
  static const shuttleCapacity   = S('Up to 14 passengers',      'حتى 14 راكباً');
  static const boardingPoint     = S('Boarding Point',           'نقطة الصعود');
  static const alightingPoint    = S('Alighting Point',          'نقطة النزول');

  // ── Searching ─────────────────────────────────────────────────────────────
  static const findingDriver     = S('Finding your driver...',   'جاري البحث عن سائق...');
  static const findingShuttle    = S('Finding your shuttle...',  'جاري البحث عن شاتل...');
  static const usually25min      = S('Usually 2–5 minutes',      'عادةً 2–5 دقائق');
  static const cancelRide        = S('Cancel Ride',              'إلغاء الرحلة');

  // ── Active Ride ───────────────────────────────────────────────────────────
  static const driverOnWay       = S('Driver is on the way',     'السائق في الطريق إليك');
  static const shuttleOnWay      = S('Shuttle is on the way',    'الشاتل في الطريق');
  static const driverArrived     = S('Driver has arrived!',      'وصل السائق!');
  static const shuttleArrived    = S('Shuttle has arrived!',     'وصل الشاتل!');
  static const onTheWay          = S('On the way',               'في الطريق');
  static const chatLabel         = S('Chat',                     'دردشة');
  static const callLabel         = S('Call',                     'اتصال');
  static const sosLabel          = S('SOS',                      'طوارئ');
  static const pickupLabel       = S('Pickup',                   'الانطلاق');
  static const destLabel         = S('Destination',              'الوجهة');
  static const fareLabel         = S('Fare (Cash)',              'الأجرة (نقدي)');

  // ── Ride Completed ────────────────────────────────────────────────────────
  static const rideCompleted     = S('Ride Completed!',          'انتهت الرحلة!');
  static const shuttleCompleted  = S('Shuttle Completed!',       'انتهى الشاتل!');
  static const rateDriver        = S('Rate your driver',         'قيّم سائقك');
  static const rateShuttleDriver = S('Rate your shuttle driver', 'قيّم سائق الشاتل');
  static const backToHome        = S('Back to Home',             'العودة للرئيسية');
  static const skipRating        = S('Skip',                     'تخطي');
  static const submitRating      = S('Submit Rating',            'إرسال التقييم');
  static const addTip            = S('Add tip (optional)',       'إضافة إكرامية (اختياري)');

  // ── History ───────────────────────────────────────────────────────────────
  static const activity          = S('Activity',                 'النشاط');
  static const noRides           = S('No rides yet',             'لا توجد رحلات بعد');
  static const firstRide         = S('Book your first ride!',    'احجز رحلتك الأولى!');

  // ── Profile ───────────────────────────────────────────────────────────────
  static const profile           = S('Profile',                  'الملف الشخصي');
  static const language          = S('Language',                 'اللغة');
  static const settings          = S('Settings',                 'الإعدادات');
  static const account           = S('Account',                  'الحساب');
  static const rideHistory       = S('Ride History',             'سجل الرحلات');
  static const helpSupport       = S('Help & Support',           'المساعدة والدعم');
  static const signOut           = S('Sign Out',                 'تسجيل الخروج');
  static const signOutConfirm    = S('Are you sure you want to sign out?',
                                     'هل أنت متأكد من تسجيل الخروج؟');
  static const cancel            = S('Cancel',                   'إلغاء');
  static const confirm           = S('Confirm',                  'تأكيد');

  // ── Driver Auth ───────────────────────────────────────────────────────────
  static const driveWithDoss     = S('Drive with DOSS',          'اقود مع DOSS');
  static const earn100           = S('Earn more, keep 100%',     'اكسب أكثر، احتفظ بـ 100%');
  static const vehiclePlate      = S('Vehicle plate',            'لوحة السيارة');
  static const vehicleModel      = S('Vehicle model',            'موديل السيارة');
  static const pendingTitle      = S('Application Under Review', 'الطلب قيد المراجعة');
  static const pendingSub        = S('Our team will review your application within 24 hours.',
                                     'سيراجع فريقنا طلبك خلال 24 ساعة.');

  // ── Driver Dashboard ──────────────────────────────────────────────────────
  static const goOnline          = S('Go Online',                'ابدأ العمل');
  static const goOffline         = S('Go Offline',               'أوقف العمل');
  static const ridesToday        = S('Rides',                    'الرحلات');
  static const acceptance        = S('Acceptance',               'القبول');
  static const earnings          = S('Earnings',                 'الأرباح');
  static const subscription      = S('Subscription',             'الاشتراك');
  static const documents         = S('Documents',                'الوثائق');
  static const activeSubLabel    = S('Active Subscription',      'اشتراك نشط');
  static const noSubLabel        = S('No Active Subscription',   'لا يوجد اشتراك نشط');
  static const expiresIn         = S('Expires in',               'ينتهي خلال');

  // ── Driver Offer ──────────────────────────────────────────────────────────
  static const newRide           = S('New Ride',                 'رحلة جديدة');
  static const newShuttleRide    = S('New Shuttle Ride',         'رحلة شاتل جديدة');
  static const acceptRide        = S('Accept Ride',              'قبول الرحلة');
  static const reject            = S('Reject',                   'رفض');
  static const iArrived          = S('I Have Arrived',           'وصلت');
  static const startRide         = S('Start Ride',               'ابدأ الرحلة');
  static const completeRide      = S('Complete Ride',            'إنهاء الرحلة');

  // ── Subscription Plans ────────────────────────────────────────────────────
  static const subscriptionPlans    = S('Subscription Plans',       'خطط الاشتراك');
  static const howToSubscribe       = S('How to Subscribe',         'كيفية الاشتراك');
  static const uploadReceipt        = S('Upload Payment Receipt',   'رفع إيصال الدفع');
  static const perDay               = S('/ day',                    '/ يوم');
  static const aiVerifies          = S('AI verifies instantly',     'الذكاء الاصطناعي يتحقق فوراً');
  static const carPlanTitle         = S('Car Driver Plan',          'خطة سائق السيارة');
  static const bikePlanTitle        = S('Bike Driver Plan',         'خطة سائق الدراجة');
  static const shuttlePlanTitle     = S('Shuttle Driver Plan',      'خطة سائق الشاتل');
  static const shuttlePlanDesc      = S('Fixed routes, lower competition, loyal riders',
                                        'خطوط ثابتة، منافسة أقل، ركاب أوفياء');
  static const carPlanDesc          = S('Standard rides across your city',
                                        'رحلات عادية في مدينتك');
  static const bikePlanDesc         = S('Short rides, fast earnings',
                                        'رحلات قصيرة، أرباح سريعة');
  static const dailySubscription    = S('Daily Subscription',       'اشتراك يومي');
  static const shuttleFeeNote       = S('350 EGP/day — Shuttle drivers earn from fixed routes',
                                        '350 جنيه/يوم — سائقو الشاتل يربحون من خطوط ثابتة');

  // ── Common ────────────────────────────────────────────────────────────────
  static const retry             = S('Retry',                    'إعادة المحاولة');
  static const loading           = S('Loading...',               'جاري التحميل...');
  static const somethingWrong    = S('Something went wrong',     'حدث خطأ ما');
  static const noInternet        = S('No internet connection',   'لا يوجد اتصال بالإنترنت');
  static const ok                = S('OK',                       'حسناً');
  static const today             = S('Today',                    'اليوم');
  static const egp               = S('EGP',                      'جنيه');
  static const km                = S('km',                       'كم');
  static const min               = S('min',                      'دقيقة');
}
