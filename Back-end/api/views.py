from calendar import calendar
import datetime
import os
import json
import threading
import tempfile
from django.utils.timezone import now
import urllib.request
import hmac
import hashlib
import subprocess
import shutil
import requests
import cv2
import numpy as np
from decimal import Decimal
from email.message import EmailMessage
import logging
from calendar import monthrange

from django.core.exceptions import ImproperlyConfigured
from celery import shared_task

from cryptography.fernet import Fernet
from sklearn.metrics.pairwise import cosine_similarity
from insightface.app import FaceAnalysis

from django.conf import settings
from django.core.mail import send_mail, get_connection
from django.http import HttpResponse, FileResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, action, authentication_classes, permission_classes
from rest_framework.response import Response
from rest_framework import viewsets, filters, status
from rest_framework.views import APIView

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import BasePermission, AllowAny

import firebase_admin
from firebase_admin import credentials, firestore, storage, auth as firebase_auth

from django.core.mail import EmailMultiAlternatives

from .mixins import CachedListMixin
from django.db import transaction

from .models import (
    AttendanceLog, IssueReport, Order, Songs, Product, Users, Overseer, District, Community, 
    OverseerCommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch, AdminStaffMember, AuditLog,
    TactsoCommitteeMember, ApplicationRequest, UserUniversityApplication, 
    SellerListing, ContributionHistory, MonthlyReport,Visitor,EventContribution,EventDiary
)

from .serializers import (
    AdminStaffMemberSerializer, IssueReportSerializer, OrderSerializer, SongSerializer, ProductSerializer, UsersSerializer, 
    OverseerSerializer, DistrictSerializer, CommunitySerializer, 
    OverseerCommitteeMemberSerializer, OverseerExpenseReportSerializer, 
    UpcomingEventSerializer, CareerOpportunitySerializer, 
    TactsoBranchSerializer,AdminStaffMemberSerializer, AuditLogSerializer,
    TactsoCommitteeMemberSerializer, ApplicationRequestSerializer,EventContributionSerializer,EventDiarySerializer,
    UserUniversityApplicationSerializer, SellerListingSerializer, ContributionHistorySerializer, MonthlyReportSerializer,VisitorSerializer
)

logger = logging.getLogger(__name__)

# ==========================================
# 1. INITIALIZATION & SETUP
# ==========================================

if hasattr(settings, 'ENCRYPTION_KEY') and settings.ENCRYPTION_KEY:
    try:
        cipher_suite = Fernet(settings.ENCRYPTION_KEY)
    except Exception as e:
        logger.critical(f"Encryption Init Failed: {e}")
        raise ImproperlyConfigured(f"Invalid ENCRYPTION_KEY: {e}")
else:
    logger.critical("CRITICAL SECURITY WARNING: No ENCRYPTION_KEY found in settings.")
    raise ImproperlyConfigured("ENCRYPTION_KEY must be set in production to prevent complete data loss.")

try:
    GLOBAL_FACE_APP = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    GLOBAL_FACE_APP.prepare(ctx_id=0)
    logger.info("✅ InsightFace model loaded.")
except Exception as e:
    GLOBAL_FACE_APP = None
    logger.error(f"❌ Error loading InsightFace: {e}")

if not firebase_admin._apps:
    firebase_config = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if firebase_config:
        try: 
            if os.path.exists(str(firebase_config)): 
                cred = credentials.Certificate(firebase_config)
            else: 
                cred_dict = json.loads(firebase_config)
                cred = credentials.Certificate(cred_dict)
            bucket_name = getattr(settings, 'FIREBASE_STORAGE_BUCKET', 'tact-3c612.appspot.com')
            firebase_admin.initialize_app(cred, {
                'storageBucket': bucket_name
            })
            logger.info(f"✅ Firebase initialized: {bucket_name}")
        except Exception as e:
            logger.error(f"❌ Firebase Init Error: {e}")
    else:
        logger.warning("⚠️ Warning: FIREBASE_SERVICE_ACCOUNT_JSON missing in .env")

# ==========================================
# 1.5 CUSTOM SECURITY MIDDLEWARE (FIREBASE AUTH)
# ==========================================

class FirebaseUser:
    def __init__(self, uid, decoded_token):
        self.uid = uid
        self.decoded_token = decoded_token
        self.is_authenticated = True

class FirebaseAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        if not auth_header:
            return None
        try:
            token = auth_header.split(' ')[1]
            decoded_token = firebase_auth.verify_id_token(token)
            uid = decoded_token.get('uid')
            user = FirebaseUser(uid, decoded_token)
            return (user, token)
        except Exception as e:
            raise AuthenticationFailed(f"Invalid or expired Firebase Token: {str(e)}")

class IsFirebaseAuthenticated(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and getattr(request.user, 'is_authenticated', False))

# ==========================================
# 2. HELPER FUNCTIONS (Security, AI, Email)
# ==========================================

def generate_face_encoding(file_obj):
    if GLOBAL_FACE_APP is None: return "[]"
    try:
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        for chunk in file_obj.chunks():
            temp_file.write(chunk)
        temp_file.close()

        img = cv2.imread(temp_file.name)
        if img is None: return "[]"
        faces = GLOBAL_FACE_APP.get(img)
        if not faces: return "[]"
        
        # Sort by largest face bounding box
        faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
        embedding = faces[0].embedding.tolist()
        return json.dumps(embedding)
    except Exception as e:
        logger.error(f"Face Encoding Generation Error: {e}")
        return "[]"
    finally:
        if 'temp_file' in locals() and os.path.exists(temp_file.name):
            os.remove(temp_file.name)
        file_obj.seek(0)  # CRITICAL: Reset the file pointer for Firebase upload
def encrypt_and_upload_to_firebase(file_obj, folder):
    if not cipher_suite: return None
    try:
        file_data = file_obj.read()
        encrypted_data = cipher_suite.encrypt(file_data)
        bucket = storage.bucket()
        filename = f"{folder}/{os.urandom(16).hex()}.enc"
        blob = bucket.blob(filename)
        blob.upload_from_string(encrypted_data, content_type='application/octet-stream')
        blob.make_public()
        return blob.public_url
    except Exception as e:
        logger.error(f"Encryption Upload Error: {e}")
        return None
    
def upload_to_firebase(file_obj, folder):
    """
    Uploads a file to Firebase Storage without encryption.
    Returns the public URL or None on failure.
    """
    try:
        bucket = storage.bucket()
        # Generate a unique filename with original extension
        ext = file_obj.name.split('.')[-1] if '.' in file_obj.name else 'jpg'
        filename = f"{folder}/{os.urandom(16).hex()}.{ext}"
        blob = bucket.blob(filename)
        file_data = file_obj.read()
        blob.upload_from_string(file_data, content_type=file_obj.content_type or 'application/octet-stream')
        blob.make_public()
        return blob.public_url
    except Exception as e:
        logger.error(f"Firebase upload error: {e}")
        return None
def decrypt_from_url_to_temp(url):
    if not cipher_suite: return None
    try:
        with requests.get(url, stream=True, timeout=120) as response:
            response.raise_for_status()
            encrypted_data = response.content
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        temp_file.write(decrypted_data)
        temp_file.close()
        return temp_file.name
    except Exception as e:
        logger.error(f"Decryption Error: {e}")
        return None

def perform_verification(live_path, ref_path, is_encrypted_ref):
    if GLOBAL_FACE_APP is None: return {'matched': False, 'error': 'AI Engine Down'}
    real_ref_path = ref_path
    temp_files_to_clean = []
    try:
        if is_encrypted_ref:
            real_ref_path = decrypt_from_url_to_temp(ref_path)
            if not real_ref_path: return {'matched': False, 'error': 'Decryption failed'}
            temp_files_to_clean.append(real_ref_path)
        elif ref_path.startswith('http'):
            legacy_temp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
            urllib.request.urlretrieve(ref_path, legacy_temp)
            real_ref_path = legacy_temp
            temp_files_to_clean.append(legacy_temp)
        def get_embedding(path):
            img = cv2.imread(path)
            if img is None: return None
            faces = GLOBAL_FACE_APP.get(img)
            if not faces: return None
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            return faces[0].embedding
        emb_live = get_embedding(live_path)
        emb_ref = get_embedding(real_ref_path)
        if emb_live is None or emb_ref is None: return {'matched': False, 'error': 'Face not detected'}
        sim = cosine_similarity(emb_live.reshape(1, -1), emb_ref.reshape(1, -1))[0][0]
        return {'matched': sim > 0.50, 'score': float(sim)}
    except Exception as e:
        return {'matched': False, 'error': str(e)}
    finally:
        for p in temp_files_to_clean:
            if os.path.exists(p): os.remove(p)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def recognize_face(request):
    live_file = request.FILES.get('live_image')
    ref_url = request.data.get('reference_url')
    candidates_json = request.data.get('candidates')

    if not live_file: return Response({'error': 'Missing live image data'}, status=400)
    if not ref_url and not candidates_json: return Response({'error': 'Missing verification targets'}, status=400)

    temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
    try:
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)

        if candidates_json:
            # FAST PATH: Check against all loaded encodings at once natively
            try:
                candidates = json.loads(candidates_json)
            except Exception:
                return Response({'error': 'Invalid candidates JSON format'}, status=400)

            img = cv2.imread(temp_live)
            if img is None: return Response({'matched': False, 'message': 'Invalid live image format'})
            faces = GLOBAL_FACE_APP.get(img)
            if not faces: return Response({'matched': False, 'message': 'No face detected in live feed'})
            
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            emb_live = faces[0].embedding.reshape(1, -1)

            best_match_id = None
            highest_sim = 0.0

            for cand in candidates:
                try:
                    encoding_data = cand.get('encoding', '[]')
                    if not encoding_data or encoding_data == '[]': continue
                    
                    encoding_list = json.loads(encoding_data)
                    emb_ref = np.array(encoding_list).reshape(1, -1)
                    sim = cosine_similarity(emb_live, emb_ref)[0][0]
                    
                    if sim > 0.50 and sim > highest_sim:
                        highest_sim = float(sim)
                        best_match_id = cand.get('id')
                except Exception as e:
                    continue

            if best_match_id:
                return Response({'matched': True, 'matched_id': best_match_id, 'distance': highest_sim})
            return Response({'matched': False, 'message': 'Face did not match any committee members'})

        else:
            # LEGACY PATH: Decrypting/Downloading 1-to-1 URL match
            is_encrypted = ref_url.endswith('.enc') or '.enc?' in ref_url
            result = perform_verification(temp_live, ref_url, is_encrypted)
            if result.get('error'): return Response({'matched': False, 'message': result['error']})
            return Response({'matched': result['matched'], 'distance': result.get('score', 0.0)})
    finally:
        if os.path.exists(temp_live): os.remove(temp_live)
        
        
@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def upload_poster(request):
    """
    Uploads a poster image to Firebase Storage and returns the public URL.
    Expects a file in the 'poster' field.
    """
    file_obj = request.FILES.get('poster')
    if not file_obj:
        return Response({'error': 'No poster file provided'}, status=400)

    try:
        bucket = storage.bucket()
        # Generate a unique filename
        ext = file_obj.name.split('.')[-1] if '.' in file_obj.name else 'jpg'
        filename = f"posters/{os.urandom(16).hex()}.{ext}"
        blob = bucket.blob(filename)
        # Read file content and upload
        file_data = file_obj.read()
        blob.upload_from_string(file_data, content_type=file_obj.content_type or 'image/jpeg')
        # Make public
        blob.make_public()
        logger.info(f"✅ Poster uploaded: {blob.public_url}")
        return Response({'url': blob.public_url}, status=201)
    except Exception as e:
        logger.error(f"❌ Poster upload error: {e}")
        return Response({'error': str(e)}, status=500)
    
    
@shared_task
def process_bulk_email_task(include_terms, include_policy):
    try:
        db = firestore.client()
        docs = db.collection('users').stream()
        connection = get_connection()
        connection.open()
        terms_link = "https://dankiemobile.org.za/terms-and-conditions"
        policy_link = "https://dankiemobile.org.za/policy-privacy"
        for doc in docs:
            u = doc.to_dict()
            email = u.get('email')
            if email:
                body = f"Dear Member,\n\nWe have updated our legal documents.\n"
                if include_terms: body += f"Terms: {terms_link}\n"
                if include_policy: body += f"Privacy: {policy_link}\n"
                try:
                    send_mail("Important Legal Update", body, settings.EMAIL_HOST_USER, [email], connection=connection, fail_silently=True)
                except Exception as e: 
                    logger.error(f"Failed sending email to {email}: {e}")
        connection.close()
    except Exception as e:
        logger.error(f"Error in email process: {e}")

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def send_legal_broadcast(request):
    inc_terms = request.data.get('include_terms', False)
    inc_policy = request.data.get('include_policy', False)
    if not inc_terms and not inc_policy: return Response({'error': 'Select document type.'}, status=400)
    process_bulk_email_task.delay(inc_terms, inc_policy)
    return Response({'message': 'Broadcast started via background worker.'})

class ServeDecryptedImageView(APIView):
    authentication_classes = []
    permission_classes = []
    def get(self, request):
        encrypted_url = request.query_params.get('url')
        if not encrypted_url: 
            return HttpResponse("Missing URL", status=400)
        try:
            response = requests.get(encrypted_url)
            if response.status_code != 200: 
                return HttpResponse("Failed to fetch image", status=404)
            decrypted_data = cipher_suite.decrypt(response.content)
            content_type = "application/octet-stream"
            if decrypted_data.startswith(b'%PDF'):
                content_type = "application/pdf"
            elif decrypted_data.startswith(b'\xff\xd8\xff'):
                content_type = "image/jpeg"
            elif decrypted_data.startswith(b'\x89PNG\r\n\x1a\n'):
                content_type = "image/png"
            http_response = HttpResponse(decrypted_data, content_type=content_type)
            http_response['Content-Disposition'] = 'inline'
            return http_response
        except Exception as e:
            logger.error(f"Error serving decrypted file: {e}")
            return HttpResponse(f"Error: {e}", status=500)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def initialize_subscription(request):
    logger.info("----- DEBUG: SUBSCRIPTION REQUEST START -----")
    logger.info(f"Incoming Data: {request.data}") 
    try:
        email = request.data.get('email')
        uid = request.data.get('uid')
        plan_code = request.data.get('plan_code')
        member_count = request.data.get('member_count', 0)
        if not all([email, uid, plan_code]):
            logger.error(f"❌ Validation Failed. Missing fields. Email: {email}, UID: {uid}, Plan: {plan_code}")
            return Response({'error': 'Missing required subscription details.'}, status=400)
        reference = f"SUB_{uid}_{int(datetime.datetime.now().timestamp())}"
        paystack_url = f"{settings.PAYSTACK_API_BASE}/transaction/initialize"
        body = {
            "email": email,
            "amount": "0",
            "plan": plan_code,
            "currency": "ZAR",
            "reference": reference,
            "callback_url": "https://standard.paystack.co/close",
            "metadata": {
                "custom_fields": [
                    {"display_name": "Subscription_Type", "variable_name": "subscription_type", "value": "monthly_overseer_tier"},
                    {"display_name": "overseer_uid", "variable_name": "overseer_uid", "value": uid},
                    {"display_name": "Plan_Code", "variable_name": "plan_code", "value": plan_code},
                    {"display_name": "Member_Count", "variable_name": "member_count", "value": str(member_count)},
                ]
            }
        }
        headers = {
            "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
            "Content-Type": "application/json",
        }
        logger.info(f"🚀 Sending to Paystack: {paystack_url}")
        resp = requests.post(paystack_url, json=body, headers=headers)
        data = resp.json()
        logger.info(f"📩 Paystack Response: {data}") 
        if not data.get('status'):
            error_msg = data.get('message', 'Paystack initialization failed.')
            logger.error(f"❌ Paystack Error: {error_msg}")
            return Response({'error': error_msg}, status=400)
        logger.info("✅ Success! URL generated.")
        return Response({'authorization_url': data['data']['authorization_url']})
    except Exception as e:
        logger.error(f"🔥 EXCEPTION: {str(e)}")
        return Response({'error': str(e)}, status=500)  

@csrf_exempt
def paystack_webhook(request):
    if request.method != 'POST':
        return HttpResponse("Method not allowed", status=405)
    secret = settings.PAYSTACK_SECRET_KEY
    if not secret:
        logger.error("🚨 WEBHOOK ERROR: PAYSTACK_SECRET_KEY is missing from settings configuration.")
        return HttpResponse("Server Error", status=500)
    signature = request.headers.get('x-paystack-signature')
    if not signature:
        logger.warning("🚨 WEBHOOK WARNING: Received request completely lacking 'x-paystack-signature' header.")
        return HttpResponse("No signature", status=401)
    try:
        hash_calc = hmac.new(
            secret.encode('utf-8'), 
            request.body, 
            digestmod=hashlib.sha512
        ).hexdigest()
        if hash_calc != signature:
            logger.warning("🚨 WEBHOOK WARNING: Security signature validation calculation failed. Header mismatch.")
            return HttpResponse("Unauthorized", status=401)
    except Exception as e:
        logger.error(f"🚨 WEBHOOK EXCEPTION: Signature Verification parsing anomaly: {e}")
        return HttpResponse("Server Error", status=500)
    try:
        event = json.loads(request.body)
        logger.info(f"ℹ️ WEBHOOK DATA: Received webhook payload successfully decoded. Event type: {event.get('event')}")
    except json.JSONDecodeError as json_err:
        logger.error(f"🚨 WEBHOOK ERROR: JSON body could not be decoded. Raw string context: {request.body}. Error: {json_err}")
        return HttpResponse("Invalid JSON", status=400)

    event_type = event.get('event')
    data = event.get('data', {})
    metadata = data.get('metadata', {})
    if not isinstance(metadata, dict):
        metadata = {}
    metadata_fields = metadata.get('custom_fields', [])
    
    def get_meta(variable_name):
        field = next((f for f in metadata_fields if f.get('variable_name') == variable_name), None)
        return field['value'] if field else None

    if event_type == 'charge.success' and data.get('status') == 'success':
        subscription_type = get_meta('subscription_type')
        contribution_type = get_meta('contribution_type')
        if contribution_type == 'event_contribution':
            event_id = get_meta('event_id')
            overseer_id = get_meta('overseer_id')
            paid_cents = int(data.get('amount', 0))
            paid_zar = Decimal(str(paid_cents)) / Decimal('100')
            if not event_id or not overseer_id:
                logger.error("🚨 WEBHOOK ERROR: Event Contribution triggered, but missing required metadata parameters.")
                return HttpResponse('Missing metadata.', status=400)
            try:
                updated_count = EventContribution.objects.filter(
                    event__id=event_id,
                    overseer__id=overseer_id
                ).update(
                    has_contributed=True,
                    amount=paid_zar,
                    remarks="Successfully Paid via Paystack"
                )
                if updated_count > 0:
                    logger.info(f"✅ Event Contribution Verified: Overseer {overseer_id} paid R{paid_zar} for Event {event_id}")
                else:
                    logger.warning(f"⚠️ Event Contribution matched no pending record for Event {event_id}, Overseer {overseer_id}")
                return HttpResponse('Event contribution verified.', status=200)
            except Exception as e:
                logger.error(f"❌ Error updating event contribution: {e}")
                return HttpResponse('Internal server error.', status=500)
        elif subscription_type == 'monthly_overseer_tier':
            overseer_uid = get_meta('overseer_uid')
            member_count_val = get_meta('member_count')
            if not overseer_uid:
                logger.info("Event received, but missing 'overseer_uid'.")
                return HttpResponse('Event received, but not a valid subscription charge.', status=200)
            auth_code = data.get('authorization', {}).get('authorization_code')
            paystack_email = data.get('customer', {}).get('email')
            charged_amount_cents = data.get('amount')
            if not auth_code or not paystack_email:
                logger.error(f"Missing vital data in subscription charge for UID: {overseer_uid}")
                return HttpResponse('Missing critical data in payload.', status=200)
            try:
                next_charge_date = datetime.datetime.now() + datetime.timedelta(days=30)
                current_member_count = int(member_count_val) if member_count_val else 0 
                Overseer.objects.update_or_create(
                    uid=overseer_uid,
                    defaults={
                        'paystack_auth_code': auth_code,
                        'paystack_email': paystack_email,
                        'subscription_status': 'active',
                        'last_charged': datetime.datetime.now(),
                        'last_charged_amount': Decimal(str(charged_amount_cents)) / Decimal('100'), 
                        'current_member_count': current_member_count,
                        'next_charge_date': next_charge_date
                    }
                )
                logger.info(f"✅ Overseer {overseer_uid} successfully subscribed/authorized.")
                return HttpResponse('Subscription webhook processed.', status=200)
            except Exception as e:
                logger.error(f"❌ Error processing subscription charge for {overseer_uid}: {e}")
                return HttpResponse('Internal server error during DB update.', status=500)
        else:
            order_ref = data.get('reference')
            try: 
                order = Order.objects.get(id=order_ref)
                expected_cents = int(order.total_amount * Decimal('100'))
                paid_cents = int(data.get('amount', 0))
                logger.info(f"ℹ️ WEBHOOK MATH CHECK: Order reference '{order_ref}'. Expected Cents: {expected_cents}, Paystack Paid Cents: {paid_cents}")
                if expected_cents == paid_cents:
                    order.is_paid = True
                    order.status = 'paid'
                    order.transaction_id = str(data.get('id'))
                    order.paystack_transaction_data = data
                    order.save()
                    logger.info(f"✅ Order {order_ref} updated to paid.")
                    return HttpResponse('Webhook received and order updated.', status=200)
                else:
                    logger.error(f"⚠️ Amount mismatch for Order {order_ref}: Expected {expected_cents}, got {paid_cents}")
                    return HttpResponse('Amount mismatch', status=400)
            except Order.DoesNotExist:
                logger.warning(f"⚠️ Order reference '{order_ref}' not found in local database models during process execution sequence.")
                return HttpResponse('Order not found', status=400)
            except Exception as e:
                logger.error(f"❌ Error updating order status: {e}")
                return HttpResponse('Internal server error.', status=500)
    elif event_type == 'charge.failure':
        overseer_uid = get_meta('overseer_uid')
        contribution_type = get_meta('contribution_type')
        if contribution_type == 'event_contribution':
            event_id = get_meta('event_id')
            overseer_id = get_meta('overseer_id')
            logger.warning(f"⚠️ Payment failed for Event Contribution. Event: {event_id}, Overseer: {overseer_id}")
            return HttpResponse('Event contribution failure logged.', status=200)
        elif overseer_uid:
            try:
                Overseer.objects.filter(uid=overseer_uid).update(
                    subscription_status='payment_failed',
                    last_attempted=datetime.datetime.now()
                )
                logger.info(f"⚠️ Initial charge failed for overseer {overseer_uid}.")
            except Exception as e:
                logger.error(f"❌ Error handling failure for {overseer_uid}: {e}")
        return HttpResponse('Webhook received.', status=200)
    return HttpResponse('Webhook received.', status=200)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def create_seller_subaccount(request):
    logger.info(f"Subaccount Request Data: {request.data}") 
    uid = request.data.get('uid') 
    business_name = request.data.get('business_name')
    bank_code = request.data.get('bank_code')
    account_number = request.data.get('account_number')
    contact_email = request.data.get('contact_email')
    if not all([uid, business_name, bank_code, account_number, contact_email]):
         return Response({'error': 'Missing required fields (uid, business_name, etc.)'}, status=400)
    try: 
        user = Users.objects.get(uid=uid)
    except Users.DoesNotExist:
        return Response({'error': f"User with uid {uid} not found"}, status=404)
    platform_fee = 9.0 
    payload = {
        "business_name": business_name,
        "settlement_bank": bank_code,
        "account_number": account_number,
        "percentage_charge": platform_fee, 
        "primary_contact_email": contact_email,
    }
    headers = {
        "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    try:
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/subaccount", json=payload, headers=headers)
        data = resp.json()
        logger.info(f"Paystack Response: {data}")
        if resp.status_code == 200 or resp.status_code == 201:
            if data.get('status') is True:
                sub_code = data['data']['subaccount_code']
                user.seller_paystack_account = sub_code 
                user.save()
                return Response({'success': True, 'subaccount_code': sub_code})
            else:
                return Response({'error': data.get('message')}, status=400)
        else:
            return Response({'error': data.get('message', 'Paystack validation failed')}, status=400)
    except Exception as e:
        logger.error(f"Server Error: {str(e)}")
        return Response({'error': str(e)}, status=500)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def create_payment_link(request):
    try:
        email = request.data.get('email')
        products = request.data.get('products', [])
        order_ref = request.data.get('orderReference')
        contribution_type = request.data.get('contribution_type')
        event_id = request.data.get('event_id')
        overseer_id = request.data.get('overseer_id')

        if not email or not products or not order_ref:
            return Response({'error': 'Invalid request body'}, status=400)
        total_amount = 0
        subaccounts = []
        for product in products:
            price = Decimal(str(product.get('price', 0)))
            qty = Decimal(str(product.get('quantity', 1)))
            amount_cents = int(price * qty * Decimal('100'))
            total_amount += amount_cents
            if product.get('subaccount'): 
                ADMIN_SHARE_PERCENT = getattr(settings, 'ADMIN_SHARE_PERCENT', 9)
                seller_share = int(amount_cents * Decimal(str(1 - ADMIN_SHARE_PERCENT / 100.0)))
                subaccounts.append({
                    "subaccount": product['subaccount'],
                    "share": seller_share
                })
        try:
            db_order = Order.objects.get(id=order_ref)
            expected_db_cents = int(db_order.total_amount * Decimal('100'))
            if expected_db_cents > total_amount:
                logger.info(f"ℹ️ PAYMENT LINK CALCULATION ADJUSTMENT: Appending missing metadata/delivery delta of {expected_db_cents - total_amount} cents.")
                total_amount = expected_db_cents
        except Order.DoesNotExist:
            pass
        body = {
            "email": email,
            "amount": total_amount,
            "currency": "ZAR",
            "channels": ['card', 'bank', 'ussd', 'qr', 'mobile_money'],
            "reference": order_ref, 
        }
        if contribution_type == 'event_contribution' and event_id and overseer_id:
            body['metadata'] = {
                "custom_fields": [
                    {"display_name": "Contribution Type", "variable_name": "contribution_type", "value": "event_contribution"},
                    {"display_name": "Event ID", "variable_name": "event_id", "value": event_id},
                    {"display_name": "Overseer ID", "variable_name": "overseer_id", "value": overseer_id},
                ]
            }
        if subaccounts:
            body['split'] = {
                "type": "flat",
                "subaccounts": subaccounts
            }
        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}"}
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/transaction/initialize", json=body, headers=headers)
        data = resp.json()
        if not data.get('status'):
            return Response({'error': data.get('message')}, status=400)
        return Response({'paymentLink': data['data']['authorization_url']})
    except Exception as e: 
        logger.error(f"Payment Link Error: {e}")
        return Response({'error': 'Server error'}, status=500)
 
# ===========================================================================================================
# 4. MODEL VIEWSETS
# ===========================================================================================================
import threading
import time
from geopy.geocoders import Nominatim
from django.db import connection

# --- NEW BACKGROUND TASK ---
def batch_geocode_communities(community_ids):
    """
    Runs in the background to prevent server timeouts.
    Includes a 1.5-second sleep to respect Nominatim's strict ToS.
    """
    try:
        from .models import Community # Import inside to avoid circular dependencies
        geolocator = Nominatim(user_agent="tact_backend_v2_smart_search")
        
        for cid in community_ids:
            try:
                # Use select_related to prevent missing relations in background thread
                community = Community.objects.select_related('district__overseer').get(id=cid)
                overseer = community.district.overseer
                
                region = getattr(overseer, 'region', '') or ''
                province = getattr(overseer, 'province', '') or ''
                c_name = getattr(community, 'community_name', '') or ''
                
                # Build safe search strings
                address_attempts = []
                if c_name and region and province:
                    address_attempts.append(f"{c_name}, {region}, {province}, South Africa")
                if c_name and province:
                    address_attempts.append(f"{c_name}, {province}, South Africa")
                if c_name:
                    address_attempts.append(f"{c_name}, South Africa")
                
                for address in address_attempts:
                    try:
                        time.sleep(1.5)  # CRITICAL: Prevents IP bans from Nominatim
                        location = geolocator.geocode(address, timeout=10)
                        if location:
                            Community.objects.filter(id=cid).update(
                                latitude=location.latitude,
                                longitude=location.longitude,
                                full_address=address
                            )
                            break 
                    except Exception as geo_err:
                        print(f"Geocoding iteration failed: {geo_err}")
                        continue 
            except Exception as e:
                print(f"Error processing community {cid}: {e}")
                pass
    finally:
        # Prevents database connection leaks in background threads
        connection.close()


class OverseerViewSet(CachedListMixin, viewsets.ModelViewSet):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsFirebaseAuthenticated()]
    
    def get_authenticators(self):
        if self.request.method == 'GET':
            return []
        return [FirebaseAuthentication()]
    
    queryset = Overseer.objects.all()
    serializer_class = OverseerSerializer

    def get_queryset(self): 
        queryset = Overseer.objects.prefetch_related('districts__communities').all()
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email__iexact=email.strip())
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid.strip())
        province_param = self.request.query_params.get('province')
        if province_param: queryset = queryset.filter(province__iexact=province_param.strip())
        return queryset

    def create(self, request, *args, **kwargs): 
        data = request.data.dict() if hasattr(request.data, 'dict') else request.data.copy()
        districts_data = []
        
        if 'districts' in data:
            try:
                raw_districts = data.pop('districts') 
                if isinstance(raw_districts, str):
                    parsed = json.loads(raw_districts)
                else:
                    parsed = raw_districts
                    
                # ⭐️ SMART PARSING: Safely convert Flutter's Map/Dict into the expected List
                if isinstance(parsed, dict):
                    for elder_name, comms in parsed.items():
                        districts_data.append({
                            'district_elder_name': elder_name,
                            'communities': comms
                        })
                elif isinstance(parsed, list):
                    districts_data = parsed
                    
            except Exception as e:
                return Response({"error": f"Invalid districts JSON format: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
        
        data['districts'] = [] 
        sec_file = request.FILES.get('secretary_face_image')
        sec_enc = "[]"
        if sec_file:
            sec_enc = generate_face_encoding(sec_file)
            data['secretary_face_url'] = encrypt_and_upload_to_firebase(sec_file, 'secure_faces')
            
        chair_file = request.FILES.get('chairperson_face_image')
        chair_enc = "[]"
        if chair_file:
            chair_enc = generate_face_encoding(chair_file)
            data['chairperson_face_url'] = encrypt_and_upload_to_firebase(chair_file, 'secure_faces') 
        
        serializer = self.get_serializer(data=data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        self.perform_create(serializer)
        overseer = serializer.instance
        
        if data.get('secretary_name') and data.get('secretary_face_url'):
            OverseerCommitteeMember.objects.create(
                overseer=overseer, full_name=data['secretary_name'], portfolio='Secretary', face_url=data['secretary_face_url'], face_encorded_json=sec_enc
            )
        if data.get('chairperson_name') and data.get('chairperson_face_url'):
            OverseerCommitteeMember.objects.create(
                overseer=overseer, full_name=data['chairperson_name'], portfolio='Chairperson', face_url=data['chairperson_face_url'], face_encorded_json=chair_enc
            )
        
        created_community_ids = []

        for d_data in districts_data:
            district = District.objects.create(
                overseer=overseer,
                district_elder_name=d_data.get('district_elder_name', 'Unknown')
            )
            for c_data in d_data.get('communities', []):
                comm = Community.objects.create(
                    district=district,
                    community_name=c_data.get('community_name', 'Unknown')
                )
                created_community_ids.append(comm.id)

        # ⭐️ Safely trigger geocoding on a separate thread
        if created_community_ids:
            threading.Thread(
                target=batch_geocode_communities, 
                args=(created_community_ids,)
            ).start()

        return Response(serializer.data, status=status.HTTP_201_CREATED)

# ⭐️ OPTIMIZED
class CommunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Community.objects.select_related('district', 'district__overseer').all()
    serializer_class = CommunitySerializer
    
    def get_permissions(self):
        if self.request.method == 'GET': 
            return [AllowAny()]
        return [IsFirebaseAuthenticated()]
        
    def get_authenticators(self):
        if self.request.method == 'GET': 
            return []
        return [FirebaseAuthentication()]
        
    def get_queryset(self):
        queryset = Community.objects.select_related('district', 'district__overseer').all()
        province = self.request.query_params.get('province')
        district__overseer_uid = self.request.query_params.get('district__overseer_uid')
        if province: 
            queryset = queryset.filter(district__overseer__province__iexact=province)
        if district__overseer_uid: 
            queryset = queryset.filter(district__overseer__uid=district__overseer_uid)
        return queryset
    
class StaffMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = AdminStaffMember.objects.all() 
    serializer_class = AdminStaffMemberSerializer
    def get_queryset(self):
        queryset = AdminStaffMember.objects.all()
        face_url = self.request.query_params.get('face_url')
        if face_url: queryset = queryset.filter(face_url__iexact=face_url)
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email__iexact=email)
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid__iexact=uid)
        return queryset
    def create(self, request, *args, **kwargs):
        data = request.data.dict() if hasattr(request.data, 'dict') else request.data.copy()
        face_file = request.FILES.get('face_image')
        if face_file:
            data['face_encorded_json'] = generate_face_encoding(face_file)
            secure_url = encrypt_and_upload_to_firebase(face_file, 'secure_faces')
            if secure_url: 
                data['face_url'] = secure_url
            else: 
                return Response({"error": "Failed to encrypt and upload face."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            return Response({"error": "Face image is required for biometric access."}, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    
    @action(detail=False, methods=['get'])
    def find_by_face(self,request):
        url = request.query_params.get('url')
        if not url: return Response({"error": "Missing url"}, status=400)
        staff = AdminStaffMember.objects.filter(face_url=url).first()
        if not staff: return Response({"error": "Not found"}, status=404)
        return Response(self.get_serializer(staff).data)

class UsersViewSet(viewsets.ModelViewSet):
    queryset = Users.objects.all()
    serializer_class = UsersSerializer
    lookup_field = 'uid'
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsFirebaseAuthenticated()]
    def get_authenticators(self):
        if self.request.method == 'GET':
            return []
        return [FirebaseAuthentication()]
    def get_queryset(self):
        queryset = Users.objects.all()
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email=email)
        role = self.request.query_params.get('role')
        if role: queryset = queryset.filter(role=role)
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid: queryset = queryset.filter(overseer_uid=overseer_uid)
        community_name = self.request.query_params.get('community_name')
        if community_name: queryset = queryset.filter(community_name__iexact=community_name.strip())
        district_elder_name = self.request.query_params.get('district_elder_name')
        if district_elder_name: queryset = queryset.filter(district_elder_name__iexact=district_elder_name.strip())
        return queryset
    def create(self, request, *args, **kwargs):
        uid = request.data.get('uid')
        if not uid: return Response({"error": "UID is required"}, status=400)
        user_instance, created = Users.objects.get_or_create(uid=uid)
        serializer = self.get_serializer(user_instance, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        attendance_status = request.data.get('attendance_status')
        if attendance_status:
            instance = self.get_object()
            is_present = (attendance_status == 'Present')
            
            target_date_str = request.data.get('date')
            if target_date_str:
                try:
                    target_date = datetime.datetime.strptime(target_date_str, "%Y-%m-%d").date()
                except ValueError:
                    target_date = now().date()
            else:
                target_date = now().date()

            if is_present: instance.last_attended_date = target_date
            AttendanceLog.objects.update_or_create(
                member_uid=instance.uid, date=target_date,
                defaults={'community_name': instance.community_name, 'is_visitor': False, 'is_present': is_present}
            )
        return super().update(request, *args, **kwargs)

    @action(detail=True, methods=['post'])
    def submit_verification(self, request, uid=None):
        user = self.get_object()
        signature_file = request.FILES.get('signature')
        id_file = request.FILES.get('id_document')
        face_file = request.FILES.get('face_image')
        if not all([signature_file, id_file, face_file]):
            return Response({"error": "Missing signature, id_document, or face_image files."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            sig_url = encrypt_and_upload_to_firebase(signature_file, 'secure_signatures')
            id_url = encrypt_and_upload_to_firebase(id_file, 'secure_ids')
            face_url = encrypt_and_upload_to_firebase(face_file, 'secure_faces')
            if not all([sig_url, id_url, face_url]):
                return Response({"error": "Failed to encrypt and securely store files."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            user.contract_signature_url = sig_url
            user.id_document_url = id_url
            user.face_image_url = face_url
            user.verification_status = "Pending Live Check"
            user.save()
            return Response({"message": "Files encrypted and securely stored.", "face_image_url": face_url}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class VisitorViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = Visitor.objects.all()
    serializer_class = VisitorSerializer
    def get_queryset(self):
        queryset = Visitor.objects.all()
        community = self.request.query_params.get('community_name')
        if community: queryset = queryset.filter(community_name__iexact=community.strip())
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid: queryset = queryset.filter(overseer_uid=overseer_uid)
        return queryset
    
    def update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        attendance_status = request.data.get('attendance_status')
        if attendance_status:
            instance = self.get_object()
            is_present = (attendance_status == 'Present')
            
            target_date_str = request.data.get('date')
            if target_date_str:
                try:
                    target_date = datetime.datetime.strptime(target_date_str, "%Y-%m-%d").date()
                except ValueError:
                    target_date = now().date()
            else:
                target_date = now().date()

            if is_present: instance.last_attended_date = target_date
            AttendanceLog.objects.update_or_create(
                member_uid=str(instance.id), date=target_date,
                defaults={'community_name': instance.community_name, 'is_visitor': True, 'is_present': is_present}
            )
        return super().update(request, *args, **kwargs)

@api_view(['GET'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def monthly_attendance_report(request):
    community = request.query_params.get('community_name')
    month = int(request.query_params.get('month'))
    year = int(request.query_params.get('year'))
    if not community or not month or not year:
        return Response({'error': 'Missing parameters'}, status=400)
    _, num_days = monthrange(year, month)
    logs = AttendanceLog.objects.filter(
        community_name__iexact=community.strip(),
        date__year=year,
        date__month=month
    )
    log_dict = {}
    for log in logs:
        if log.member_uid not in log_dict:
            log_dict[log.member_uid] = {}
        log_dict[log.member_uid][log.date.day] = log.is_present
    users = Users.objects.filter(community_name__iexact=community.strip())
    visitors = Visitor.objects.filter(community_name__iexact=community.strip())
    report_data = []
    def process_member(member, is_visitor):
        uid_key = str(member.id) if is_visitor else member.uid
        attendance = log_dict.get(uid_key, {})
        total_present = sum(1 for status in attendance.values() if status)
        total_absent = num_days - total_present 
        percentage = (total_present / num_days) * 100 if num_days > 0 else 0
        visitor_cat = getattr(member, 'visitor_category', 'Registered') if is_visitor else 'Registered'
        visitor_role = getattr(member, 'visitor_role', '') if is_visitor else ''
        report_data.append({
            'uid': uid_key, 'name': member.name, 'surname': member.surname,
            'gender': member.gender, 'is_visitor': is_visitor, 'visitor_category': visitor_cat,
            'visitor_role': visitor_role, 'attendance': attendance, 'total_present': total_present,
            'total_absent': total_absent, 'percentage': round(percentage, 1)
        })
    for u in users: process_member(u, False)
    for v in visitors: process_member(v, True)
    return Response({
        'community_name': community, 'month': month, 'year': year,
        'num_days': num_days, 'data': report_data
    })

class TactsoBranchViewSet(viewsets.ModelViewSet):
    queryset = TactsoBranch.objects.all()
    serializer_class = TactsoBranchSerializer
    def get_queryset(self):
        queryset = TactsoBranch.objects.all()
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        return queryset
    def create(self, request, *args, **kwargs):
        data = request.data.dict()
        if 'image_url' not in data: data['image_url'] = ""
        auth_faces = []
        
        officer_file = request.FILES.get('education_officer_face_image')
        officer_enc = "[]"
        if officer_file:
            officer_enc = generate_face_encoding(officer_file)
            url = encrypt_and_upload_to_firebase(officer_file, 'secure_faces')
            if url:
                data['education_officer_face_url'] = url
                auth_faces.append(url)
            else: return Response({"error": "Failed to encrypt Officer face"}, status=500)
        else: return Response({"error": "Education Officer face is required"}, status=400)
        
        chair_file = request.FILES.get('chairperson_face_image')
        chair_url = None
        chair_enc = "[]"
        if chair_file:
            chair_enc = generate_face_encoding(chair_file)
            chair_url = encrypt_and_upload_to_firebase(chair_file, 'secure_faces')
            if chair_url: auth_faces.append(chair_url)
            else: return Response({"error": "Failed to encrypt Chairperson face"}, status=500)
        else: return Response({"error": "Chairperson face is required"}, status=400)
        
        data['authorized_user_face_urls'] = json.dumps(auth_faces)
        serializer = self.get_serializer(data=data)
        if not serializer.is_valid(): return Response(serializer.errors, status=400)
        self.perform_create(serializer)
        branch = serializer.instance
        
        TactsoCommitteeMember.objects.create(
            branch=branch, full_name=data.get('education_officer_name', 'Education Officer'),
            portfolio='Education Officer', email=data.get('email', ''), face_url=data['education_officer_face_url'], face_encorded_json=officer_enc
        )
        TactsoCommitteeMember.objects.create(
            branch=branch, full_name=data.get('chairperson_name', 'Chairperson'),
            portfolio='Chairperson', email=data.get('email', ''), face_url=chair_url, face_encorded_json=chair_enc
        )
        return Response(serializer.data, status=201)
class DistrictViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = District.objects.select_related('overseer').prefetch_related('communities').all()
    serializer_class = DistrictSerializer
    def get_permissions(self):
        if self.request.method == 'GET': return [AllowAny()]
        return [IsFirebaseAuthenticated()]
    def get_authenticators(self):
        if self.request.method == 'GET': return []
        return [FirebaseAuthentication()]
    def get_queryset(self):
        queryset = District.objects.select_related('overseer').prefetch_related('communities').all()
        province = self.request.query_params.get('province')
        limit = self.request.query_params.get('limit')
        overseer_uid = self.request.query_params.get('overseer_uid')
        if province and province != 'All': queryset = queryset.filter(overseer__province__iexact=province)
        if overseer_uid: queryset = queryset.filter(overseer__uid=overseer_uid)
        if limit:
            try: return queryset[:int(limit)]
            except ValueError: pass
        return queryset

class SongViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = Songs.objects.all()
    serializer_class = SongSerializer

class CatalogViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'category']

# ⭐️ OPTIMIZED
class SellerInventoryViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    serializer_class = SellerListingSerializer
    queryset = SellerListing.objects.select_related('seller').all()
    def get_queryset(self):
        queryset = SellerListing.objects.select_related('seller').all()
        seller_uid_param = self.request.query_params.get('seller_uid')
        if seller_uid_param: queryset = queryset.filter(seller__uid=seller_uid_param)
        return queryset
    def perform_create(self, serializer): serializer.save()

class OrderViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    serializer_class = OrderSerializer 
    queryset = Order.objects.select_related('user').prefetch_related('items__product').all()
    def get_queryset(self):
        queryset = Order.objects.select_related('user').prefetch_related('items__product').all()
        user_uid = self.request.query_params.get('user_uid')
        if user_uid: 
            queryset = queryset.filter(user__uid=user_uid)
        seller_uid = self.request.query_params.get('seller_uid')
        if seller_uid:
            queryset = queryset.filter(items__product__seller__uid=seller_uid).distinct()
        return queryset
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    def perform_create(self, serializer): serializer.save()
    @action(detail=True, methods=['get'], authentication_classes=[], permission_classes=[AllowAny])
    def verify_payment(self, request, pk=None):
        order = self.get_object()
        if order.status == 'paid' and order.is_paid: return Response(self.get_serializer(order).data)
        url = f"https://api.paystack.co/transaction/verify/{order.id}"
        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}"}
        try:
            resp = requests.get(url, headers=headers)
            data = resp.json()
            if data['status'] and data['data']['status'] == 'success':
                paid_cents = int(data['data']['amount'])
                expected_cents = int(order.total_amount * Decimal('100'))
                if paid_cents >= expected_cents:
                    order.is_paid = True
                    order.status = 'paid'
                    order.transaction_id = str(data['data']['id'])
                    order.paystack_transaction_data = data['data']
                    order.save()
                    logger.info(f"Order {order.id} verified and updated to PAID.")
            return Response(self.get_serializer(order).data)
        except Exception as e:
            logger.error(f"Verification Error: {e}")
            return Response(self.get_serializer(order).data)

# ⭐️ OPTIMIZED
class OverseerCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerCommitteeMember.objects.select_related('overseer').all()
    serializer_class = OverseerCommitteeMemberSerializer
    def create(self, request, *args, **kwargs):
        overseer_id = request.data.get('overseer')
        if overseer_id:
            current_count = OverseerCommitteeMember.objects.filter(overseer__id=overseer_id).count()
            if current_count >= 30: return Response({"error": "Maximum limit of 30 committee members reached."}, status=status.HTTP_400_BAD_REQUEST)
        data = request.data.dict() if hasattr(request.data, 'dict') else request.data.copy()
        face_file = request.FILES.get('face_image')
        
        if face_file:
            data['face_encorded_json'] = generate_face_encoding(face_file)
            secure_url = encrypt_and_upload_to_firebase(face_file, 'secure_faces')
            if secure_url: data['face_url'] = secure_url
            else: return Response({"error": "Failed to encrypt and upload face."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else: return Response({"error": "Face image is strictly required."}, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    def get_queryset(self):
        queryset = OverseerCommitteeMember.objects.select_related('overseer').all()
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email__iexact=email.strip())
        overseer_id = self.request.query_params.get('overseer')
        if overseer_id: queryset = queryset.filter(overseer__id=overseer_id)
        face_url = self.request.query_params.get('face_url')
        if face_url: queryset = queryset.filter(face_url=face_url)
        return queryset

class OverseerExpenseReportViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerExpenseReport.objects.all()
    serializer_class = OverseerExpenseReportSerializer
    def get_queryset(self):
        queryset = OverseerExpenseReport.objects.all()
        month = self.request.query_params.get('month')
        year = self.request.query_params.get('year')
        limit = self.request.query_params.get('limit')
        if month and month != 'All': queryset = queryset.filter(month__iexact=month) 
        if year and year != 'All': queryset = queryset.filter(year=year)
        if limit:
            try: return queryset[:int(limit)]
            except: pass
        return queryset   
     
class UpcomingEventViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = UpcomingEvent.objects.all()
    serializer_class = UpcomingEventSerializer

class CareerOpportunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = CareerOpportunity.objects.all()
    serializer_class = CareerOpportunitySerializer

# ⭐️ OPTIMIZED
class BranchCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet): 
    authentication_classes = [FirebaseAuthentication] 
    permission_classes = [IsFirebaseAuthenticated] 
    queryset = TactsoCommitteeMember.objects.select_related('branch').all() 
    serializer_class = TactsoCommitteeMemberSerializer 
    
    def create(self, request, *args, **kwargs):
        branch_id = request.data.get('branch')
        if branch_id:
            current_count = TactsoCommitteeMember.objects.filter(branch__id=branch_id).count()
            if current_count >= 6: 
                return Response({"error": "Maximum limit of 6 committee members reached."}, status=status.HTTP_400_BAD_REQUEST)
        
        data = request.data.dict() if hasattr(request.data, 'dict') else request.data.copy()
        face_file = request.FILES.get('face_image')
        
        if face_file:
            data['face_encorded_json'] = generate_face_encoding(face_file)
            secure_url = encrypt_and_upload_to_firebase(face_file, 'secure_faces')
            if secure_url: 
                data['face_url'] = secure_url
            else: 
                return Response({"error": "Failed to encrypt and upload face."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else: 
            return Response({"error": "Face image is strictly required."}, status=status.HTTP_400_BAD_REQUEST)
            
        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    
    
# ⭐️ OPTIMIZED
class ApplicationRequestViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = ApplicationRequest.objects.select_related('branch', 'user').all()
    serializer_class = ApplicationRequestSerializer
    def get_queryset(self):
        queryset = ApplicationRequest.objects.select_related('branch', 'user').all()
        branch_id = self.request.query_params.get('branch')
        if branch_id: queryset = queryset.filter(branch__id=branch_id)
        user_uid = self.request.query_params.get('user_uid')
        if user_uid: queryset = queryset.filter(user__uid=user_uid)
        return queryset
    def create(self, request, *args, **kwargs):
        data = request.data.dict()
        def encrypt_field(field_name):
            file_obj = request.FILES.get(field_name)
            if file_obj:
                secure_url = encrypt_and_upload_to_firebase(file_obj, 'secure_applications')
                if secure_url: data[field_name] = secure_url
                else: raise Exception(f"Failed to encrypt {field_name}")
        try:
            encrypt_field('id_passport_url')
            encrypt_field('school_results_url')
            encrypt_field('proof_of_registration_url')
            encrypt_field('other_qualifications_url')
            serializer = self.get_serializer(data=data)
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            headers = self.get_success_headers(serializer.data)
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class UserUniversityApplicationViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = UserUniversityApplication.objects.all()
    serializer_class = UserUniversityApplicationSerializer
 
class AuditLogViewSet(viewsets.ModelViewSet): 
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = AuditLog.objects.all().order_by('-timestamp')
    serializer_class = AuditLogSerializer
    def get_queryset(self):
        queryset = AuditLog.objects.all().order_by('-timestamp')
        uid = self.request.query_params.get('uid')
        if uid:
            queryset = queryset.filter(uid=uid)
        return queryset

class ContributionHistoryViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = ContributionHistory.objects.all()
    serializer_class = ContributionHistorySerializer
    def get_queryset(self):
        qs = ContributionHistory.objects.all()
        overseer = self.request.query_params.get('overseer_uid')
        elder = self.request.query_params.get('district_elder')
        community = self.request.query_params.get('community')
        year = self.request.query_params.get('year')
        month = self.request.query_params.get('month')
        if overseer: qs = qs.filter(overseer_uid=overseer)
        if elder: qs = qs.filter(district_elder=elder)
        if community: qs = qs.filter(community=community)
        if year: qs = qs.filter(year=year)
        if month: qs = qs.filter(month=month)
        return qs

class MonthlyReportViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = MonthlyReport.objects.all()
    serializer_class = MonthlyReportSerializer
    lookup_field = 'id'
    @action(detail=False, methods=['post'])
    def archive_month(self, request):
        data = request.data
        overseer_uid = data.get('overseer_uid')
        elder = data.get('district_elder')
        community = data.get('community')
        year = data.get('year')
        month = data.get('month')
        province = data.get('province')
        report_data = data.get('report_data', {})
        expenses_data = data.get('expenses_data', {})
        if not all([overseer_uid, elder, community, year, month]):
            return Response({'error': 'Missing required fields'}, status=400)
        try:
            with transaction.atomic():
                users = Users.objects.filter(overseer_uid=overseer_uid, district_elder_name=elder, community_name=community)
                history_records = []
                for user in users:
                    history_records.append(ContributionHistory(
                        overseer_uid=overseer_uid, user_uid=user.uid, name=user.name, surname=user.surname,
                        district_elder=elder, community=community, month=month, year=year,
                        week1=float(user.week1 or 0), week2=float(user.week2 or 0), week3=float(user.week3 or 0), week4=float(user.week4 or 0),
                    ))
                    user.week1 = "0"
                    user.week2 = "0"
                    user.week3 = "0"
                    user.week4 = "0"
                    user.save()
                ContributionHistory.objects.bulk_create(history_records)
                report_id = f"{community}_{year}_{month}"
                MonthlyReport.objects.update_or_create(
                    id=report_id,
                    defaults={'community_name': community, 'year': year, 'month': month, **report_data}
                )
                OverseerExpenseReport.objects.create(**expenses_data)
            return Response({'status': 'success', 'message': 'Month archived successfully'})
        except Exception as e:
            return Response({'error': str(e)}, status=500)

@api_view(['GET'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def global_attendance_summary(request):
    """
    Returns aggregated attendance AND full attendee list for a given date.
    Query param: date (YYYY-MM-DD)
    Response: list of objects with:
        overseer_name, province, region,
        total_present, brothers_present, sisters_present,
        parents_present, visitors_present,
        testifies_present, ready_testifies,
        attendees: [ {name, surname, gender, role, category, overseer_name} ]
    """
    date_str = request.query_params.get('date')
    if not date_str:
        return Response({'error': 'Missing date parameter (YYYY-MM-DD)'}, status=400)
    try:
        target_date = datetime.datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return Response({'error': 'Invalid date format. Use YYYY-MM-DD.'}, status=400)

    present_logs = AttendanceLog.objects.filter(date=target_date, is_present=True)

    user_uids = set()
    visitor_ids = set()
    for log in present_logs:
        if log.is_visitor:
            visitor_ids.add(log.member_uid)
        else:
            user_uids.add(log.member_uid)

    users_map = {u.uid: u for u in Users.objects.filter(uid__in=user_uids)}
    visitors_map = {str(v.id): v for v in Visitor.objects.filter(id__in=visitor_ids)}

    overseer_stats = {}  # key: overseer_uid

    # Pre‑fetch all overseers that will be needed
    overseer_uids = set()
    for log in present_logs:
        if log.is_visitor:
            visitor = visitors_map.get(log.member_uid)
            if visitor:
                overseer_uids.add(visitor.overseer_uid)
        else:
            user = users_map.get(log.member_uid)
            if user:
                overseer_uids.add(user.overseer_uid)
    overseer_map = {o.uid: o for o in Overseer.objects.filter(uid__in=overseer_uids)}

    for log in present_logs:
        overseer_uid = None
        gender = ''
        category = ''
        is_ready = False
        visitor_role = None
        name = ''
        surname = ''

        if log.is_visitor:
            visitor = visitors_map.get(log.member_uid)
            if not visitor:
                continue
            overseer_uid = visitor.overseer_uid
            gender = visitor.gender
            category = visitor.visitor_category
            is_ready = visitor.ready_for_membership
            visitor_role = visitor.visitor_role or visitor.visitor_category or 'Visitor'
            name = visitor.name
            surname = visitor.surname
        else:
            user = users_map.get(log.member_uid)
            if not user:
                continue
            overseer_uid = user.overseer_uid
            gender = user.gender
            category = 'Member'
            is_ready = False
            name = user.name
            surname = user.surname

        if not overseer_uid:
            continue

        if overseer_uid not in overseer_stats:
            overseer_stats[overseer_uid] = {
                'total_present': 0,
                'brothers_present': 0,
                'sisters_present': 0,
                'parents_present': 0,
                'visitors_present': 0,
                'testifies_present': 0,
                'ready_testifies': 0,
                'attendees': [],
            }

        stats = overseer_stats[overseer_uid]
        stats['total_present'] += 1

        gender_lower = gender.lower() if gender else ''
        display_role = 'Member'

        if log.is_visitor:
            if category in ['Mother', 'Father']:
                stats['parents_present'] += 1
                display_role = category
                if visitor_role and visitor_role != 'None':
                    display_role += f" ({visitor_role})"
            else:
                stats['visitors_present'] += 1
                stats['testifies_present'] += 1
                if is_ready:
                    stats['ready_testifies'] += 1
                display_role = visitor_role if visitor_role and visitor_role != 'None' else category
        else:
            # 🔥 FIX: Only Members can be counted as Brothers or Sisters
            if gender_lower == 'male':
                stats['brothers_present'] += 1
                display_role = 'Brother'
            elif gender_lower == 'female':
                stats['sisters_present'] += 1
                display_role = 'Sister'
            else:
                display_role = 'Member'

        # Get the overseer's name for this attendee
        overseer_obj = overseer_map.get(overseer_uid)
        overseer_name = overseer_obj.overseer_initials_surname if overseer_obj else 'Unknown'

        # Append attendee WITH overseer_name
        stats['attendees'].append({
            'name': name,
            'surname': surname,
            'gender': gender,
            'role': display_role,
            'category': category,
            'overseer_name': overseer_name,
        })

    # Build final response
    result = []
    for overseer_uid, stats in overseer_stats.items():
        overseer = overseer_map.get(overseer_uid)
        if not overseer:
            continue
        result.append({
            'overseer_name': overseer.overseer_initials_surname,
            'province': overseer.province,
            'region': overseer.region,
            'total_present': stats['total_present'],
            'brothers_present': stats['brothers_present'],
            'sisters_present': stats['sisters_present'],
            'parents_present': stats['parents_present'],
            'visitors_present': stats['visitors_present'],
            'testifies_present': stats['testifies_present'],
            'ready_testifies': stats['ready_testifies'],
            'attendees': stats['attendees'],
        })

    return Response(result, status=200)


class IssueReportViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = IssueReport.objects.all()
    serializer_class = IssueReportSerializer
    def get_queryset(self):
        qs = IssueReport.objects.all()
        is_resolved = self.request.query_params.get('is_resolved') 
        if is_resolved is not None: qs = qs.filter(is_resolved=(is_resolved.lower() == 'true')) 
        return qs

class EventDiaryViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = EventDiary.objects.all()
    serializer_class = EventDiarySerializer
    def get_queryset(self):
        queryset = EventDiary.objects.all()
        year = self.request.query_params.get('year')
        if year: queryset = queryset.filter(year=year)
        return queryset

# ⭐️ OPTIMIZED
class EventContributionViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = EventContribution.objects.select_related('event', 'overseer').all()
    serializer_class = EventContributionSerializer
    def get_queryset(self):
        queryset = EventContribution.objects.select_related('event', 'overseer').all()
        event_id = self.request.query_params.get('event_id')
        overseer_uid = self.request.query_params.get('overseer_uid')
        if event_id: queryset = queryset.filter(event__id=event_id)
        if overseer_uid: queryset = queryset.filter(overseer__uid=overseer_uid)
        return queryset
 
from .models import ApostolicGreeting
from .serializers import ApostolicGreetingSerializer

class ApostolicGreetingViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = ApostolicGreeting.objects.all()
    serializer_class = ApostolicGreetingSerializer
    lookup_field = 'id'
    @action(detail=True, methods=['post']) 
    def like(self, request, id=None): 
        greeting = self.get_object() 
        greeting.likes += 1 
        greeting.save() 
        return Response({'likes': greeting.likes, 'views': greeting.views})
    @action(detail=True, methods=['post']) 
    def view_greeting(self, request, id=None): 
        greeting = self.get_object() 
        greeting.views += 1 
        greeting.save() 
        return Response({'likes': greeting.likes, 'views': greeting.views})
    
@api_view(['GET'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsFirebaseAuthenticated])
def user_attendance(request):
    """
    Returns attendance stats and history for a specific user or visitor.
    Query params:
      - uid (required) – the member uid or visitor id
      - is_visitor (optional, default false) – whether this is a visitor
      - year (optional) – filter to a specific year
    """
    uid = request.query_params.get('uid')
    if not uid:
        return Response({'error': 'Missing uid parameter'}, status=400)

    is_visitor = request.query_params.get('is_visitor', 'false').lower() == 'true'
    year_param = request.query_params.get('year')

    # Build queryset
    logs = AttendanceLog.objects.filter(member_uid=uid, is_visitor=is_visitor)
    if year_param:
        logs = logs.filter(date__year=int(year_param))

    logs = logs.order_by('-date')

    total = logs.count()
    present_count = logs.filter(is_present=True).count()
    absent_count = total - present_count
    percentage = (present_count / total) if total > 0 else 0.0
 
    history = []
    for log in logs[:20]:
        history.append({
            'date': log.date.isoformat(),
            'status': 'Present' if log.is_present else 'Absent',
        })

    return Response({
        'stats': {
            'total': total,
            'present': present_count,
            'absent': absent_count,
            'percentage': round(percentage, 2),
        },
        'history': history,
    })

 
from rest_framework import viewsets
from .models import Users, Overseer, OverseerCommitteeMember
from .models import OverseerDiaryEvent, OverseerMeetingMinutes, OverseerCommunication, CommunicationReadStatus
from .serializers import (
    OverseerDiaryEventSerializer, OverseerMeetingMinutesSerializer,
    OverseerCommunicationSerializer, CommunicationReadStatusSerializer
)
class OverseerDiaryEventViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerDiaryEvent.objects.select_related('overseer').all()
    serializer_class = OverseerDiaryEventSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid:
            queryset = queryset.filter(overseer__uid=overseer_uid)
        return queryset

    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        poster_file = request.FILES.get('poster')
        if poster_file:
            url = upload_to_firebase(poster_file, 'posters')
            if url:
                data['poster_url'] = url
            else:
                return Response({"error": "Failed to upload poster"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        data = request.data.copy()
        poster_file = request.FILES.get('poster')
        if poster_file:
            url = upload_to_firebase(poster_file, 'posters')
            if url:
                data['poster_url'] = url
            else:
                return Response({"error": "Failed to upload poster"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        return Response(serializer.data)

    def perform_create(self, serializer):
        auth_user = Users.objects.filter(uid=self.request.user.uid).first()
        if auth_user and auth_user.email:
            member = OverseerCommitteeMember.objects.filter(email=auth_user.email).first()
            if member:
                serializer.save(created_by=member)
                return
        serializer.save()

    def perform_update(self, serializer):
        auth_user = Users.objects.filter(uid=self.request.user.uid).first()
        if auth_user and auth_user.email:
            member = OverseerCommitteeMember.objects.filter(email=auth_user.email).first()
            if member:
                serializer.save(created_by=member)
                return
        serializer.save()
        
class OverseerMeetingMinutesViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerMeetingMinutes.objects.select_related('overseer').all()  # ✅ Removed 'created_by'
    serializer_class = OverseerMeetingMinutesSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid:
            queryset = queryset.filter(overseer__uid=overseer_uid)
        return queryset

    def perform_create(self, serializer):
        auth_user = Users.objects.filter(uid=self.request.user.uid).first()
        if auth_user and auth_user.email:
            member = OverseerCommitteeMember.objects.filter(email=auth_user.email).first()
            if member:
                serializer.save(created_by=member)
                return
        serializer.save()


# 3. Overseer Communications (Fixed select_related)
class OverseerCommunicationViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerCommunication.objects.select_related('overseer').prefetch_related('read_statuses').all() # ✅ Removed 'created_by'
    serializer_class = OverseerCommunicationSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid:
            queryset = queryset.filter(overseer__uid=overseer_uid)

        is_published = self.request.query_params.get('is_published')
        if is_published is not None:
            if is_published.lower() == 'true':
                queryset = queryset.filter(is_published=True)
            elif is_published.lower() == 'false':
                queryset = queryset.filter(is_published=False)
        return queryset

    def perform_create(self, serializer):
        auth_user = Users.objects.filter(uid=self.request.user.uid).first()
        if auth_user and auth_user.email:
            member = OverseerCommitteeMember.objects.filter(email=auth_user.email).first()
            if member:
                # Also handle attachments if they are passed in files
                uploaded_files = self.request.FILES.getlist('attachments')
                attachment_urls = []
                if uploaded_files:
                    from .views import encrypt_and_upload_to_firebase # Ensure this helper is imported
                    for file_obj in uploaded_files:
                        url = encrypt_and_upload_to_firebase(file_obj, 'communications')
                        if url:
                            attachment_urls.append(url)
                serializer.save(created_by=member, attachments=attachment_urls)
                return
        serializer.save()


# 4. Communication Read Status
class CommunicationReadStatusViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = CommunicationReadStatus.objects.select_related('communication', 'user').all()
    serializer_class = CommunicationReadStatusSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        communication_id = self.request.query_params.get('communication_id')
        user_uid = self.request.query_params.get('user_uid')
        if communication_id:
            queryset = queryset.filter(communication__id=communication_id)
        if user_uid:
            queryset = queryset.filter(user__uid=user_uid)
        return queryset

    def perform_create(self, serializer):
        auth_user = Users.objects.filter(uid=self.request.user.uid).first()
        if auth_user:
            serializer.save(user=auth_user)
        else:
            serializer.save()