import os
import sys
import json
import django
import firebase_admin
from firebase_admin import credentials, firestore
from django.conf import settings

# ===============================================================
# 1. SETUP DJANGO ENVIRONMENT
# ===============================================================
# Add the current directory to python path so it finds 'tact_api'
current_dir = os.path.dirname(os.path.abspath(__file__)) # .../Back-end/api
parent_dir = os.path.dirname(current_dir)                # .../Back-end
sys.path.append(parent_dir)

# 2. FIX THE MODULE NAME
# Your folder is named 'api', so we must use 'api.settings', not 'tact_api.settings'
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "tact_api.settings")
django.setup()

# Import models AFTER django.setup()
from api.models import (
    Product, Songs, OverseerExpenseReport, UpcomingEvent, Overseer, 
    District, Community, CareerOpportunity, TactsoBranch,  
    StaffMember, CommitteeMember, AuditLog, ApplicationRequest, 
    BranchCommitteeMember, Users
)

# ===============================================================
# 2. SETUP FIREBASE (RAILWAY COMPATIBLE)
# ===============================================================
print("🔥 Connecting to Firebase...")

# Get the secret JSON from the Railway Environment Variable
firebase_config = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')

if not firebase_config:
    print("❌ CRITICAL ERROR: 'FIREBASE_SERVICE_ACCOUNT_JSON' variable not found.")
    print("   -> Ensure you added this variable in Railway Dashboard.")
    sys.exit(1)

try:
    # Parse the string into a dictionary
    cred_dict = json.loads(firebase_config)
    cred = credentials.Certificate(cred_dict)
    
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    print("✅ Firebase Connected Successfully!")
    
except Exception as e:
    print(f"❌ Error initializing Firebase: {e}")
    sys.exit(1)

# ===============================================================
# 3. MIGRATE DATA
# ===============================================================

# --- SONGS ---
print("\n🎵 Migrating 'tact_music'...")
songs_ref = db.collection("tact_music")
s_count, s_skipped = 0, 0
for doc in songs_ref.stream():
    data = doc.to_dict()
    # Unique check: Artist + Song Name
    if not Songs.objects.filter(song_name=data.get("songName"), artist=data.get("artist")).exists():
        Songs.objects.create(
            artist=data.get("artist", ""),
            category=data.get("category", ""),
            released=data.get("released") or "Unknown",
            song_name=data.get("songName", ""),
            song_url=data.get("songUrl", ""),
        )
        s_count += 1
    else:
        s_skipped += 1
print(f"   -> {s_count} added, {s_skipped} skipped.")

# --- EVENTS ---
print("\n📅 Migrating 'upcoming_events'...")
events_ref = db.collection("upcoming_events")
ev_count, ev_skipped = 0, 0
for doc in events_ref.stream():
    data = doc.to_dict()
    if not UpcomingEvent.objects.filter(title=data.get("title"), parsed_date=data.get("parsedDate")).exists():
        UpcomingEvent.objects.create(
            title=data.get("title", ""),
            poster_url=data.get("posterUrl", ""),
            day=data.get("day", ""),
            month=data.get("month", ""),
            parsed_date=data.get("parsedDate", ""),
            created_at=data.get("createdAt", "")
        )
        ev_count += 1
    else:
        ev_skipped += 1
print(f"   -> {ev_count} added, {ev_skipped} skipped.")

# --- STAFF ---
print("\n👥 Migrating 'staff_members'...")
staff_ref = db.collection("staff_members")
st_count, st_skipped = 0, 0
for doc in staff_ref.stream():
    data = doc.to_dict()
    if not StaffMember.objects.filter(uid=data.get("uid")).exists():
        StaffMember.objects.create(
            uid=data.get("uid"),
            full_name=data.get("fullName", ""),
            name=data.get("name", ""),
            surname=data.get("surname", ""),
            email=data.get("email", ""),
            role=data.get("role", "Staff"),
            portfolio=data.get("portfolio", ""),
            province=data.get("province", ""),
            face_url=data.get("faceUrl", ""),
            is_active=data.get("isActive", True),
            created_at=data.get("createdAt", "")
        )
        st_count += 1
    else:
        st_skipped += 1
print(f"   -> {st_count} added, {st_skipped} skipped.")

# --- AUDIT LOGS ---
print("\n📜 Migrating 'audit_logs'...")
audit_ref = db.collection("audit_logs")
al_count, al_skipped = 0, 0
for doc in audit_ref.stream():
    data = doc.to_dict()
    # Check if log exists (using strict matching to avoid duplicates)
    timestamp_val = str(data.get("timestamp", ""))
    if not AuditLog.objects.filter(action=data.get("action"), uid=data.get("uid"), timestamp=timestamp_val).exists():
        AuditLog.objects.create(
            action=data.get("action", ""),
            details=data.get("details", ""), 
            actor_name=data.get("actorName", ""),
            actor_role=data.get("actorRole", ""),
            actor_face_url=data.get("actorFaceUrl", ""),
            uid=data.get("uid", ""),
            university_name=data.get("universityName", ""),
            university_logo=data.get("universityLogo", ""),
            branch_email=data.get("branchEmail", ""),
            target_member_name=data.get("targetMemberName", ""),
            target_member_role=data.get("targetMemberRole", ""),
            student_name=data.get("studentName", "N/A"),
            timestamp=timestamp_val,
            device_time=data.get("deviceTime", "")
        )
        al_count += 1
    else:
        al_skipped += 1
print(f"   -> {al_count} added, {al_skipped} skipped.")

# --- USERS ---
print("\n👤 Migrating 'users'...")
users_ref = db.collection("users")
u_count, u_skipped = 0, 0
for doc in users_ref.stream():
    data = doc.to_dict()
    uid = data.get("uid")
    
    if not uid: continue

    if not Users.objects.filter(uid=uid).exists():
        try:
            Users.objects.create(
                uid=uid,
                email=data.get("email", ""),
                name=data.get("name",""),
                phone=data.get("phone", ""),
                surname=data.get("surname", ""),
                address=data.get("address", ""),
                province=data.get("province", ""),
                role=data.get("role", ""),
                community_name=data.get("communityName", ""),
                district_elder_name=data.get("districtElderName", ""),
                overseer_uid=data.get("overseerUid", ""),
                profile_url=data.get("profileUrl", ""),
                week1=str(data.get("week1", "0")),
                week2=str(data.get("week2", "0")),
                week3=str(data.get("week3", "0")),
                week4=str(data.get("week4", "0")),
                seller_paystack_account=data.get("sellerPaystackAccount", ""),
                account_verified=data.get("accountVerified", False)
            )
            u_count += 1
        except Exception as e:
            print(f"⚠️ Error on user {uid}: {e}")
    else:
        u_skipped += 1
print(f"   -> {u_count} added, {u_skipped} skipped.")

print("\n🚀 MIGRATION COMPLETE!")