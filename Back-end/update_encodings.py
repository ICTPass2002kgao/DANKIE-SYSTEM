import os
import django
import sys

# 1. Setup Django environment so we can access your models
# ⚠️ CHANGE 'tact_api' to the folder name that contains your settings.py
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tact_api.settings') 
django.setup()

import cv2
import json

# ⚠️ CHANGE 'your_app_name' to the name of your app (e.g., 'api', 'core', 'users')
from api.models import OverseerCommitteeMember, TactsoCommitteeMember, AdminStaffMember
from api.views import decrypt_from_url_to_temp, GLOBAL_FACE_APP

def process_encodings(model_class, model_name):
    print(f"\n========================================")
    print(f"🚀 STARTING: {model_name}")
    print(f"========================================")
    
    # Get all members that actually have a face_url
    members = model_class.objects.exclude(face_url='')
    
    success_count = 0
    fail_count = 0
    skip_count = 0

    for member in members:
        # Skip if they already have an encoding (saves time if the script stops halfway)
        if member.face_encorded_json and member.face_encorded_json != "[]":
            print(f"⏭️  SKIPPING: {member.full_name} (Already encoded)")
            skip_count += 1
            continue

        print(f"⏳ PROCESSING: {member.full_name}...")
        temp_path = None
        
        try:
            # 1. Download and Decrypt the image using your existing helper
            temp_path = decrypt_from_url_to_temp(member.face_url)
            if not temp_path:
                print(f"   ❌ FAILED: Could not decrypt or download image.")
                fail_count += 1
                continue
            
            # 2. Read the image with OpenCV
            img = cv2.imread(temp_path)
            if img is None:
                print(f"   ❌ FAILED: Corrupted image file.")
                fail_count += 1
                continue
                
            # 3. Detect face and generate encoding
            faces = GLOBAL_FACE_APP.get(img)
            if not faces:
                print(f"   ❌ FAILED: No face detected by AI engine.")
                # Save empty array so we don't keep trying to process a faceless image
                member.face_encorded_json = "[]"
                member.save()
                fail_count += 1
                continue
                
            # 4. Sort to get the main face and extract the list
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            embedding = faces[0].embedding.tolist()
            
            # 5. Save back to the database
            member.face_encorded_json = json.dumps(embedding)
            member.save()
            
            print(f"   ✅ SUCCESS: Encoding generated and saved.")
            success_count += 1
            
        except Exception as e:
            print(f"   ❌ ERROR: {str(e)}")
            fail_count += 1
        finally:
            # Always clean up the decrypted temp file so you don't run out of server space
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)
                
    print(f"\n📊 SUMMARY FOR {model_name}:")
    print(f"   - Success:  {success_count}")
    print(f"   - Failed:   {fail_count}")
    print(f"   - Skipped:  {skip_count}")

if __name__ == "__main__":
    if GLOBAL_FACE_APP is None:
        print("🚨 CRITICAL ERROR: InsightFace failed to load. Check your server RAM or model setup.")
        sys.exit(1)
        
    process_encodings(OverseerCommitteeMember, "Overseer Committee Members")
    process_encodings(TactsoCommitteeMember, "Tactso Branch Committee Members")
    process_encodings(AdminStaffMember, "Admin Staff Members")
    
    print("\n🎉 ALL DONE! Your database is fully updated with face encodings.")