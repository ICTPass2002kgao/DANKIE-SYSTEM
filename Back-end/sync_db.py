#!/usr/bin/env python
"""
Copy only your custom app data from Railway PostgreSQL to local SQLite.
Django internal tables (auth, admin, sessions, contenttypes) are skipped.
"""

import os
import sys
from collections import defaultdict, deque

import django
import dj_database_url
from django.apps import apps
from django.conf import settings
from django.db import connection

# 1. SETUP DJANGO
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tact_api.settings')
django.setup()

# 2. REMOTE DB CONFIG (fix missing keys)
REMOTE_DB_URL = "postgresql://postgres:tuWLitllHljFlggRCGlgUxfDIbDqSRtj@yamanote.proxy.rlwy.net:32413/railway"
db_config = dj_database_url.parse(REMOTE_DB_URL)
# Add missing keys that Django expects
db_config.setdefault('OPTIONS', {})
db_config.setdefault('TIME_ZONE', None)       # <- Fix KeyError
db_config.setdefault('CONN_MAX_AGE', 0)       # optional but safe
db_config.setdefault('AUTOCOMMIT', True)      # default
settings.DATABASES['remote'] = db_config

# 3. DETERMINE MODELS TO COPY – ONLY YOUR CUSTOM APP MODELS
SKIP_APPS = {'admin', 'auth', 'contenttypes', 'sessions', 'messages', 'staticfiles', 'humanize'}

models_to_copy = []
for model in apps.get_models():
    if model._meta.app_label in SKIP_APPS:
        continue
    if model._meta.abstract:
        continue
    models_to_copy.append(model)

print(f"Found {len(models_to_copy)} user models to copy (skipping Django internal tables).")

# 4. TOPOLOGICAL SORT (respect foreign keys)
graph = defaultdict(list)
in_degree = {model: 0 for model in models_to_copy}
model_index = {model: i for i, model in enumerate(models_to_copy)}

for model in models_to_copy:
    for field in model._meta.get_fields():
        if (field.is_relation and not field.auto_created and 
            field.related_model and field.related_model in model_index):
            graph[field.related_model].append(model)
            in_degree[model] += 1

queue = deque([m for m in models_to_copy if in_degree[m] == 0])
ordered_models = []
while queue:
    m = queue.popleft()
    ordered_models.append(m)
    for child in graph[m]:
        in_degree[child] -= 1
        if in_degree[child] == 0:
            queue.append(child)

if len(ordered_models) != len(models_to_copy):
    print("⚠️ Circular dependency detected – copying in arbitrary order.")
    ordered_models = models_to_copy

# 5. COPY DATA
def copy_data():
    # Disable FK checks on SQLite
    with connection.cursor() as cursor:
        cursor.execute("PRAGMA foreign_keys = OFF;")

    try:
        # Delete existing local data (ONLY for our custom models)
        for model in reversed(ordered_models):
            print(f"Deleting all {model._meta.db_table}...")
            model.objects.all().delete()

        # Copy from remote to local
        for model in ordered_models:
            print(f"Copying {model._meta.db_table}...")
            remote_queryset = model.objects.using('remote').all()
            instances = []
            batch_size = 1000
            count = 0

            for obj in remote_queryset.iterator():
                instances.append(obj)
                if len(instances) >= batch_size:
                    model.objects.bulk_create(instances)
                    instances = []
                    count += batch_size
                    print(f"  {count} records copied...")

            if instances:
                model.objects.bulk_create(instances)
                count += len(instances)

            print(f"  ✅ Done. {count} records copied.")

    finally:
        with connection.cursor() as cursor:
            cursor.execute("PRAGMA foreign_keys = ON;")

if __name__ == "__main__":
    print("Starting data copy from Railway PostgreSQL to local SQLite...")
    copy_data()
    print("✅ Data copy completed!")