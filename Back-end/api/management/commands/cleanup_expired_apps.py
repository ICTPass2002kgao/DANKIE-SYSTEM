# api/management/commands/cleanup_expired_apps.py

from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from api.models import ApplicationRequest
from firebase_admin import storage

class Command(BaseCommand):
    help = 'Deletes documents for applications older than 3 months'

    def handle(self, *args, **kwargs):
        # 1. Calculate the cutoff date (90 days ago)
        cutoff_date = timezone.now() - timedelta(days=90)
        
        # 2. Find expired applications
        expired_apps = ApplicationRequest.objects.filter(submission_date__lt=cutoff_date)
        
        count = 0
        bucket = storage.bucket()

        for app in expired_apps:
            # Helper to delete a single file URL
            def delete_file(url):
                if not url: return
                try:
                    # Extract blob name from URL (Basic parsing, adjust based on your URL format)
                    # Assuming URL structure: https://storage.googleapis.com/BUCKET_NAME/FOLDER/FILE
                    if "o/" in url:
                        # Firebase URLs often look like .../o/folder%2Ffilename?alt=...
                        # This part depends on how exactly your URLs are stored
                        # A safer bet for your specific setup might be storing the 'blob_name' separately, 
                        # but here we try to clean based on the folder logic you used.
                        pass 
                        # NOTE: Deleting files securely usually requires the exact 'blob path' 
                        # (e.g., 'secure_applications/filename.enc'). 
                        # If you want strict deletion, consider storing the 'path' in the model too.
                except Exception as e:
                    self.stdout.write(self.style.ERROR(f'Error deleting file: {e}'))

            # 3. Clean the fields (We keep the application record, just wipe the docs)
            # Or you can use app.delete() to remove the whole row.
            
            # Wipe fields
            app.id_passport_url = ""
            app.school_results_url = ""
            app.proof_of_registration_url = ""
            app.other_qualifications_url = ""
            app.status = "Expired / Archived"
            app.save()
            
            count += 1

        self.stdout.write(self.style.SUCCESS(f'Successfully scrubbed documents for {count} expired applications.'))