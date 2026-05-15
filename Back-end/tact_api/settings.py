"""
Django settings for tact_api project.
"""
from pathlib import Path
import os
import dj_database_url
from cryptography.fernet import Fernet
from django.core.management.utils import get_random_secret_key

# --- ENV LOADING ---
from dotenv import load_dotenv
load_dotenv() 
# -------------------

# Build paths inside the project...
BASE_DIR = Path(__file__).resolve().parent.parent

# ==========================================
# 1. SECURITY & ENVIRONMENT
# ==========================================

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', get_random_secret_key())

# SECURITY WARNING: don't run with debug turned on in production!
# On Railway, ensure you set the Environment Variable DJANGO_DEBUG = False
DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'

ALLOWED_HOSTS = [
    "127.0.0.1",
    "localhost",
    "192.168.19.151",
    "mktechcloud.co.za",
    ".railway.app",  # <--- REQUIRED FOR RAILWAY
    "*",             # CAUTION: Remove this '*' when fully live for better security
]

# ==================================================================================
# 2. CORS & CSRF (Flutter Connection)
# ==================================================================================

# CORS allows your Flutter app to make requests
CORS_ALLOW_ALL_ORIGINS = True 

# CSRF Trusted Origins (CRITICAL FOR RAILWAY)
# Railway puts your app behind a proxy (HTTPS), so Django needs to know it's safe.
CSRF_TRUSTED_ORIGINS = [
    'https://*.railway.app',
    'https://*.up.railway.app',
    'https://mktechcloud.co.za',
    'https://www.mktechcloud.co.za',
    
]

# ==========================================
# 3. INSTALLED APPS & MIDDLEWARE
# ==========================================

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles', # Required for Whitenoise
    'rest_framework',
    'corsheaders',
    'api', # Ensure your main app folder is named 'api' or change this line
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware', 
    'django.middleware.security.SecurityMiddleware',
    "whitenoise.middleware.WhiteNoiseMiddleware", # <--- MUST BE AFTER SECURITY
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'tact_api.urls' # Double check if your inner folder is named 'tact_api'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'tact_api.wsgi.application'

# ==========================================
# 4. DATABASE (Critical for Railway)
# ==========================================

# If DATABASE_URL is set (Railway), use Postgres. Otherwise SQLite (Local).
DATABASES = {
    'default': dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        conn_health_checks=True,
    )
}

# ==========================================
# 5. PASSWORD VALIDATION
# ==========================================

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ==========================================
# 6. INTERNATIONALIZATION
# ==========================================

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ==========================================
# 7. STATIC FILES (WhiteNoise Configuration)
# ==========================================

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Storage configuration for Whitenoise
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# ==========================================
# 8. EMAIL CONFIGURATION (Gmail)
# ==========================================
# # App Password (with spaces)
EMAIL_TIMEOUT = 10
 

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'setamict@gmail.com'
EMAIL_HOST_PASSWORD = 'owwa msaz ueit juum'
DEFAULT_FROM_EMAIL = 'setamict@gmail.com'

# ===============================================================================
# 9. ENCRYPTION & FIREBASE 
# ===============================================================================
 
ENCRYPTION_KEY = os.environ.get('FERNET_KEY')
 
if not ENCRYPTION_KEY:
    # Only print warning in dev, or check DEBUG status
    if DEBUG:
        print("⚠️ WARNING: FERNET_K;\/EY not found in env. Using temporary key (DATA LOSS RISK).")
    ENCRYPTION_KEY = Fernet.generate_key()
else:
    # Ensure it's bytes
    if isinstance(ENCRYPTION_KEY, str):
        ENCRYPTION_KEY = ENCRYPTION_KEY.encode()

try:
    Fernet(ENCRYPTION_KEY)
except Exception as e:
    print(f"⚠️ FATAL SECURITY ERROR: Invalid FERNET_KEY: {e}")

# Firebase
FIREBASE_SERVICE_ACCOUNT_JSON = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
FIREBASE_STORAGE_BUCKET = 'tact-3c612.firebasestorage.app'

# Paystack
PAYSTACK_SECRET_KEY = os.environ.get('PAYSTACK_SECRET_KEY')
PAYSTACK_API_BASE = os.environ.get('PAYSTACK_API_BASE')

# System Misc
APPEND_SLASH = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
 
# ==========================================
# 10. PRODUCTION HEADERS
# ==========================================

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    X_FRAME_OPTIONS = 'DENY'
    # Ensure HTTPS is recognized behind proxy
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')