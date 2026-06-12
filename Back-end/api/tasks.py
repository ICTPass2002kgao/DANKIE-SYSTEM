from celery import shared_task
from django.core.mail import send_mail, get_connection
from django.conf import settings
from firebase_admin import firestore
import logging

logger = logging.getLogger(__name__)

@shared_task
def process_bulk_email_task(include_terms, include_policy):
    try:
        db = firestore.client()
        docs = db.collection('users').stream()
        connection = get_connection()
        connection.open()
        
        terms_link = "https://dankie-website.web.app/terms_and_conditions.html"
        policy_link = "https://dankie-website.web.app/privacy_policy.html"
        
        for doc in docs:
            u = doc.to_dict()
            email = u.get('email')
            if email:
                body = "Dear Member,\n\nWe have updated our legal documents.\n"
                if include_terms: 
                    body += f"Terms: {terms_link}\n"
                if include_policy: 
                    body += f"Privacy: {policy_link}\n"
                try:
                    send_mail(
                        "Important Legal Update", 
                        body, 
                        settings.EMAIL_HOST_USER, 
                        [email], 
                        connection=connection, 
                        fail_silently=True
                    )
                except Exception as e: 
                    logger.error(f"Failed sending email to {email}: {e}")
                    
        connection.close()
    except Exception as e:
        logger.error(f"Error in email process: {e}")