import os
import django
from django.db import connection

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "tact_api.settings")
django.setup()

# Wipe Database
print("⚠️ Wiping Database...")
with connection.cursor() as cursor:
    cursor.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
print("✅ Database Wiped Successfully!")