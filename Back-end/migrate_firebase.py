# import os
# import sys
# import django
# import firebase_admin
# from firebase_admin import credentials, firestore

# # ===============================================================
# # 1. SETUP DJANGO ENVIRONMENT
# # ===============================================================
# os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tact_api.settings')
# django.setup()

# # Import models AFTER django.setup()
# from api.models import (
#     Songs, UpcomingEvent, StaffMember, AuditLog, Users,
#     Overseer, District, Community, CommitteeMember
# )

# def migrate_firebase_data():
#     print("🔥 Starting Complete Firebase Migration...")

#     # ===============================================================
#     # 2. INITIALIZE FIREBASE (Local)
#     # ===============================================================
#     try:
#         cred = credentials.Certificate('serviceAccount.json')
#         if not firebase_admin._apps:
#             firebase_admin.initialize_app(cred)
#         db = firestore.client()
#         print("✅ Successfully connected to Firebase.")
#     except Exception as e:
#         print(f"❌ Failed to connect to Firebase: {e}")
#         sys.exit(1)

#     # ===============================================================
#     # 3. MIGRATE DATA
#     # ===============================================================

#     # --- A. SONGS ---
#     print("\n🎵 Migrating 'tact_music'...")
#     songs_ref = db.collection("tact_music")
#     s_count, s_skipped = 0, 0
#     for doc in songs_ref.stream():
#         data = doc.to_dict()
#         if not data: continue
        
#         # Unique check: Artist + Song Name
#         song, created = Songs.objects.get_or_create(
#             song_name=data.get("songName", "Unknown Song"),
#             artist=data.get("artist", "Unknown Artist"),
#             defaults={
#                 'category': data.get("category", ""),
#                 'released': data.get("released") or "Unknown",
#                 'song_url': data.get("songUrl", ""),
#             }
#         )
#         if created: s_count += 1
#         else: s_skipped += 1
#     print(f"   -> {s_count} added, {s_skipped} skipped/already exist.")

#     # --- B. EVENTS ---
#     print("\n📅 Migrating 'upcoming_events'...")
#     events_ref = db.collection("upcoming_events")
#     ev_count, ev_skipped = 0, 0
#     for doc in events_ref.stream():
#         data = doc.to_dict()
#         if not data: continue

#         event, created = UpcomingEvent.objects.get_or_create(
#             title=data.get("title", "Untitled Event"),
#             parsed_date=data.get("parsedDate", ""),
#             defaults={
#                 'poster_url': data.get("posterUrl", ""),
#                 'day': data.get("day", ""),
#                 'month': data.get("month", ""),
#                 'created_at': data.get("createdAt", "")
#             }
#         )
#         if created: ev_count += 1
#         else: ev_skipped += 1
#     print(f"   -> {ev_count} added, {ev_skipped} skipped/already exist.")

#     # --- C. STAFF ---
#     print("\n👥 Migrating 'staff_members'...")
#     staff_ref = db.collection("staff_members")
#     st_count, st_skipped = 0, 0
#     for doc in staff_ref.stream():
#         data = doc.to_dict()
#         if not data: continue

#         uid = data.get("uid")
#         if not uid: continue

#         staff, created = StaffMember.objects.get_or_create(
#             uid=uid,
#             defaults={
#                 'full_name': data.get("fullName", ""),
#                 'name': data.get("name", ""),
#                 'surname': data.get("surname", ""),
#                 'email': data.get("email", ""),
#                 'role': data.get("role", "Staff"),
#                 'portfolio': data.get("portfolio", ""),
#                 'province': data.get("province", ""),
#                 'face_url': data.get("faceUrl", ""),
#                 'is_active': data.get("isActive", True),
#                 'created_at': data.get("createdAt", "")
#             }
#         )
#         if created: st_count += 1
#         else: st_skipped += 1
#     print(f"   -> {st_count} added, {st_skipped} skipped/already exist.")

#     # --- D. AUDIT LOGS ---
#     print("\n📜 Migrating 'audit_logs'...")
#     audit_ref = db.collection("audit_logs")
#     al_count, al_skipped = 0, 0
#     for doc in audit_ref.stream():
#         data = doc.to_dict()
#         if not data: continue
        
#         timestamp_val = str(data.get("timestamp", ""))
#         log, created = AuditLog.objects.get_or_create(
#             action=data.get("action", ""),
#             uid=data.get("uid", ""),
#             timestamp=timestamp_val,
#             defaults={
#                 'details': data.get("details", ""), 
#                 'actor_name': data.get("actorName", ""),
#                 'actor_role': data.get("actorRole", ""),
#                 'actor_face_url': data.get("actorFaceUrl", ""),
#                 'university_name': data.get("universityName", ""),
#                 'university_logo': data.get("universityLogo", ""),
#                 'branch_email': data.get("branchEmail", ""),
#                 'target_member_name': data.get("targetMemberName", ""),
#                 'target_member_role': data.get("targetMemberRole", ""),
#                 'student_name': data.get("studentName", "N/A"),
#                 'device_time': data.get("deviceTime", "")
#             }
#         )
#         if created: al_count += 1
#         else: al_skipped += 1
#     print(f"   -> {al_count} added, {al_skipped} skipped/already exist.")

#     # --- E. USERS ---
#     print("\n👤 Migrating 'users'...")
#     users_ref = db.collection("users")
#     u_count, u_skipped = 0, 0
#     for doc in users_ref.stream():
#         data = doc.to_dict()
#         if not data: continue

#         uid = data.get("uid")
#         if not uid: continue

#         try:
#             user, created = Users.objects.get_or_create(
#                 uid=uid,
#                 defaults={
#                     'email': data.get("email", ""),
#                     'name': data.get("name",""),
#                     'phone': data.get("phone", ""),
#                     'surname': data.get("surname", ""),
#                     'address': data.get("address", ""),
#                     'province': data.get("province", ""),
#                     'role': data.get("role", ""),
#                     'community_name': data.get("communityName", ""),
#                     'district_elder_name': data.get("districtElderName", ""),
#                     'overseer_uid': data.get("overseerUid", ""),
#                     'profile_url': data.get("profileUrl", ""),
#                     'week1': str(data.get("week1", "0")),
#                     'week2': str(data.get("week2", "0")),
#                     'week3': str(data.get("week3", "0")),
#                     'week4': str(data.get("week4", "0")),
#                     'seller_paystack_account': data.get("sellerPaystackAccount", ""),
#                     'account_verified': data.get("accountVerified", False)
#                 }
#             )
#             if created: u_count += 1
#             else: u_skipped += 1
#         except Exception as e:
#             print(f"⚠️ Error on user {uid}: {e}")
            
#     print(f"   -> {u_count} added, {u_skipped} skipped/already exist.")

#     # --- F. OVERSEERS (And Nested Data) ---
#     print("\n⛪ Migrating 'overseers' (Districts, Communities, Committees)...")
#     overseers_ref = db.collection('overseers')
#     docs = overseers_ref.stream()

#     ov_count = 0
#     for doc in docs:
#         data = doc.to_dict()
#         if not data: continue

#         uid = data.get('uid')
#         if not uid: continue

#         # 1. Create or Update Overseer
#         overseer, created = Overseer.objects.update_or_create(
#             uid=uid,
#             defaults={
#                 'overseer_initials_surname': data.get('overseerInitialsAndSurname', ''),
#                 'email': data.get('email', f"{uid}@no-email-provided.com"),
#                 'province': data.get('province', ''),
#                 'region': data.get('region', ''),
#                 'code': str(data.get('code', '')),
#                 'paystack_auth_code': data.get('paystackAuthCode', '') or '',
#                 'subscription_status': data.get('subscriptionStatus', 'inactive'),
#             }
#         )
        
#         # 2. Process Districts
#         districts_data = data.get('districts', [])
#         if isinstance(districts_data, dict):
#             districts_data = list(districts_data.values())

#         for dist_index, dist_data in enumerate(districts_data):
#             if not dist_data: continue
                
#             elder_name = dist_data.get('districtElderName', f'Unknown Elder {dist_index}')
#             district, dist_created = District.objects.get_or_create(
#                 overseer=overseer,
#                 district_elder_name=elder_name
#             )

#             # 3. Process Communities
#             communities_data = dist_data.get('communities', [])
#             if isinstance(communities_data, dict):
#                 communities_data = list(communities_data.values())

#             for comm_data in communities_data:
#                 if not comm_data: continue

#                 community_name = comm_data.get('communityName')
#                 if not community_name: continue

#                 Community.objects.get_or_create(
#                     district=district,
#                     community_name=community_name,
#                     defaults={'district_elder_name': elder_name}
#                 )

#         # 4. Process Committee Members (If stored in the Overseer document)
#         committee_data = data.get('committeeMembers', [])
#         if isinstance(committee_data, dict):
#             committee_data = list(committee_data.values())
            
#         for member in committee_data:
#             if not member: continue
            
#             member_name = member.get('name')
#             if not member_name: continue
                
#             CommitteeMember.objects.update_or_create(
#                 overseer=overseer,
#                 name=member_name,
#                 defaults={
#                     'email': member.get('email', ''),
#                     'role': member.get('role', ''),
#                     'portfolio': member.get('portfolio', ''),
#                     'face_url': member.get('faceUrl', ''),
#                     'added_at': str(member.get('addedAt', ''))
#                 }
#             )

#         ov_count += 1

#     print(f"   -> Processed {ov_count} overseers.")
#     print("\n🚀 FULL MIGRATION COMPLETE!")

# if __name__ == '__main__':
#     migrate_firebase_data()
import os
import sys
import json
import django
import firebase_admin
from firebase_admin import credentials, firestore

# ===============================================================
# 1. SETUP DJANGO ENVIRONMENT
# ===============================================================
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tact_api.settings')
django.setup()

from api.models import TactsoBranch

def migrate_tactso_branches():
    print("🔥 Starting Firebase Migration for 'tactso_branches'...")

    # ===============================================================
    # 2. INITIALIZE FIREBASE (Local)
    # ===============================================================
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate('serviceAccount.json')
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("✅ Successfully connected to Firebase.")
    except Exception as e:
        print(f"❌ Failed to connect to Firebase: {e}")
        sys.exit(1)

    # ===============================================================
    # 3. MIGRATE BRANCHES
    # ===============================================================
    print("\n🏫 Migrating 'tactso_branches'...")
    branches_ref = db.collection("tactso_branches")
    
    b_count, b_skipped, b_errors = 0, 0, 0

    for doc in branches_ref.stream():
        data = doc.to_dict()
        if not data: 
            continue

        # Use the UID from the document, fallback to document ID if missing
        uid = data.get("uid", doc.id)
        if not uid:
            continue

        # Handle the imageUrl array from Firebase (convert to JSON string for TextField)
        image_url_data = data.get("imageUrl", [])
        if not isinstance(image_url_data, list):
            image_url_data = [image_url_data] if image_url_data else []
            
        image_url_json = json.dumps(image_url_data)

        try:
            branch, created = TactsoBranch.objects.get_or_create(
                uid=uid,
                defaults={
                    'university_name': data.get("universityName", "Unknown University"),
                    'email': data.get("email", ""),
                    'address': data.get("address", ""),
                    'application_link': data.get("applicationLink", ""),
                    'has_multiple_campuses': data.get("hasMultipleCampuses", False),
                    'is_application_open': data.get("isApplicationOpen", False),
                    'created_at': str(data.get("createdAt", "")),
                    'image_url': image_url_json,
                    
                    # Fields that might not exist in early Firebase docs but are in your Django model
                    'education_officer_email': data.get("educationOfficerEmail", ""),
                    'chairperson_email': data.get("chairpersonEmail", ""),
                    'education_officer_name': data.get("educationOfficerName", ""),
                    'education_officer_face_url': data.get("educationOfficerFaceUrl", ""),
                    'authorized_user_face_urls': json.dumps(data.get("authorizedUserFaceUrls", [])),
                }
            )
            
            if created:
                b_count += 1
            else:
                b_skipped += 1
                
        except Exception as e:
            print(f"⚠️ Error migrating branch {uid}: {e}")
            b_errors += 1

    print(f"   -> {b_count} added, {b_skipped} skipped/already exist, {b_errors} errors.")
    print("\n🚀 BRANCH MIGRATION COMPLETE!")

if __name__ == '__main__':
    migrate_tactso_branches()