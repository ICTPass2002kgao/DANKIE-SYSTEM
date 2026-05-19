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
    if not live_file or not ref_url: return Response({'error': 'Missing data'}, status=400)

    temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
    try:
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)
        is_encrypted = ref_url.endswith('.enc') or '.enc?' in ref_url
        result = perform_verification(temp_live, ref_url, is_encrypted)
        if result.get('error'): return Response({'matched': False, 'message': result['error']})
        return Response({'matched': result['matched'], 'distance': result.get('score', 0.0)})
    finally:
        if os.path.exists(temp_live): os.remove(temp_live)


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
                
            # Decrypt the raw bytes
            decrypted_data = cipher_suite.decrypt(response.content)
            
            # Dynamically determine content type using file "magic bytes"
            content_type = "application/octet-stream" # Fallback
            
            if decrypted_data.startswith(b'%PDF'):
                content_type = "application/pdf"
            elif decrypted_data.startswith(b'\xff\xd8\xff'):
                content_type = "image/jpeg"
            elif decrypted_data.startswith(b'\x89PNG\r\n\x1a\n'):
                content_type = "image/png"
            
            # Send response and force the browser to display it inline
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
                    {
                        "display_name": "Subscription_Type",
                        "variable_name": "subscription_type", 
                        "value": "monthly_overseer_tier"
                    },
                    {
                        "display_name": "overseer_uid", 
                        "variable_name": "overseer_uid", 
                        "value": uid
                    },
                    {
                        "display_name": "Plan_Code", 
                        "variable_name": "plan_code", 
                        "value": plan_code
                    },
                    {
                        "display_name": "Member_Count", 
                        "variable_name": "member_count", 
                        "value": str(member_count)
                    },
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

                # Deep calculation logging to check precision drift
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
                return HttpResponse('Order not found', status=400) # Changed to 400 for structural tracking continuity
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
        data = request.data.dict() 
        districts_data = []
        if 'districts' in data:
            try:
                raw_districts = data.pop('districts') 
                if isinstance(raw_districts, str):
                    districts_data = json.loads(raw_districts)
                elif isinstance(raw_districts, list):
                    districts_data = raw_districts
            except Exception as e:
                return Response({"error": f"Invalid districts JSON format: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
 
        data['districts'] = [] 
        sec_file = request.FILES.get('secretary_face_image')
        if sec_file:
            data['secretary_face_url'] = encrypt_and_upload_to_firebase(sec_file, 'secure_faces')
        
        chair_file = request.FILES.get('chairperson_face_image')
        if chair_file:
            data['chairperson_face_url'] = encrypt_and_upload_to_firebase(chair_file, 'secure_faces') 
            
        serializer = self.get_serializer(data=data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        self.perform_create(serializer)
        overseer = serializer.instance
 
        if data.get('secretary_name') and data.get('secretary_face_url'):
            OverseerCommitteeMember.objects.create(
                overseer=overseer, full_name=data['secretary_name'], portfolio='Secretary', face_url=data['secretary_face_url']
            )
        if data.get('chairperson_name') and data.get('chairperson_face_url'):
            OverseerCommitteeMember.objects.create(
                overseer=overseer, full_name=data['chairperson_name'], portfolio='Chairperson', face_url=data['chairperson_face_url']
            )

        for d_data in districts_data:
            district = District.objects.create(
                overseer=overseer,
                district_elder_name=d_data.get('district_elder_name', 'Unknown')
            )
            for c_data in d_data.get('communities', []):
                Community.objects.create(
                    district=district,
                    community_name=c_data.get('community_name', 'Unknown')
                )

        return Response(serializer.data, status=status.HTTP_201_CREATED)

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
            if is_present: instance.last_attended_date = now().date()
            AttendanceLog.objects.update_or_create(
                member_uid=instance.uid, date=now().date(),
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
            
            return Response({
                "message": "Files encrypted and securely stored.",
                "face_image_url": face_url 
            }, status=status.HTTP_200_OK)
            
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
            if is_present: instance.last_attended_date = now().date()
            AttendanceLog.objects.update_or_create(
                member_uid=str(instance.id), date=now().date(),
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
            'ui_id': uid_key, 'name': member.name, 'surname': member.surname,
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
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
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
        if officer_file:
            url = encrypt_and_upload_to_firebase(officer_file, 'secure_faces')
            if url:
                data['education_officer_face_url'] = url
                auth_faces.append(url)
            else: return Response({"error": "Failed to encrypt Officer face"}, status=500)
        else: return Response({"error": "Education Officer face is required"}, status=400)

        chair_file = request.FILES.get('chairperson_face_image')
        chair_url = None
        if chair_file:
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
            portfolio='Education Officer', email=data.get('email', ''), face_url=data['education_officer_face_url']
        )
        TactsoCommitteeMember.objects.create(
            branch=branch, full_name=data.get('chairperson_name', 'Chairperson'),
            portfolio='Chairperson', email=data.get('email', ''), face_url=chair_url
        )
        
        return Response(serializer.data, status=201)  

class CommunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Community.objects.all()
    serializer_class = CommunitySerializer
    
    def get_permissions(self):
        if self.request.method == 'GET': return [AllowAny()]
        return [IsFirebaseAuthenticated()]

    def get_authenticators(self):
        if self.request.method == 'GET': return []
        return [FirebaseAuthentication()]
    
    def get_queryset(self):
        queryset = Community.objects.all()
        province = self.request.query_params.get('province')
        if province: queryset = queryset.filter(district__overseer__province__iexact=province)
        return queryset

class DistrictViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = District.objects.all()
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

        if province and province != 'All': queryset = queryset.filter(overseer__province__iexact=province)
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

class SellerInventoryViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    serializer_class = SellerListingSerializer
    
    def get_queryset(self):
        queryset = SellerListing.objects.all()
        seller_uid_param = self.request.query_params.get('seller_uid')
        if seller_uid_param: queryset = queryset.filter(seller__uid=seller_uid_param)
        return queryset
        
    def perform_create(self, serializer): serializer.save()

class OrderViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    serializer_class = OrderSerializer 

    def get_queryset(self):
        queryset = Order.objects.prefetch_related('items__product').select_related('user').all()
        
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

class OverseerCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = OverseerCommitteeMember.objects.all()
    serializer_class = OverseerCommitteeMemberSerializer
    
    def create(self, request, *args, **kwargs):
        overseer_id = request.data.get('overseer')
        if overseer_id:
            current_count = OverseerCommitteeMember.objects.filter(overseer__id=overseer_id).count()
            if current_count >= 5: return Response({"error": "Maximum limit of 5 committee members reached."}, status=status.HTTP_400_BAD_REQUEST)
        
        data = request.data.dict() if hasattr(request.data, 'dict') else request.data.copy()
        face_file = request.FILES.get('face_image')
        if face_file:
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
        queryset = OverseerCommitteeMember.objects.all()
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

class BranchCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = TactsoCommitteeMember.objects.all()
    serializer_class = TactsoCommitteeMemberSerializer
    
    def create(self, request, *args, **kwargs):
        branch_id = request.data.get('branch')
        if branch_id:
            current_count = TactsoCommitteeMember.objects.filter(branch__id=branch_id).count()
            if current_count >= 5: return Response({"error": "Maximum limit of 5 committee members reached."}, status=status.HTTP_400_BAD_REQUEST)
        return super().create(request, *args, **kwargs)

class ApplicationRequestViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = ApplicationRequest.objects.all()
    serializer_class = ApplicationRequestSerializer

    def get_queryset(self):
        queryset = ApplicationRequest.objects.all()
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
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    filter_backends = [filters.OrderingFilter, filters.SearchFilter]
    ordering_fields = ['timestamp', 'action']
    ordering = ['-timestamp']
    
    def get_queryset(self):
        queryset = super().get_queryset()
        timestamp = self.request.query_params.get('timestamp')
        if timestamp: queryset = queryset.filter(timestamp=timestamp)
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

class EventContributionViewSet(CachedListMixin, viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsFirebaseAuthenticated]
    queryset = EventContribution.objects.all()
    serializer_class = EventContributionSerializer

    def get_queryset(self):
        queryset = EventContribution.objects.all()
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