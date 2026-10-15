"""
Firebase authentication classes for Django REST Framework.

Kept in a separate module (away from views.py) so that settings.py can
reference them via DEFAULT_AUTHENTICATION_CLASSES without triggering a
circular import through rest_framework.views.
"""

import firebase_admin
from firebase_admin import auth as firebase_auth

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import BasePermission


class FirebaseUser:
    """Lightweight user object attached to request.user after token verification."""

    def __init__(self, uid, decoded_token):
        self.uid = uid
        self.decoded_token = decoded_token
        self.is_authenticated = True


class FirebaseAuthentication(BaseAuthentication):
    """
    Verifies a Firebase ID token supplied as:
        Authorization: Bearer <firebase-id-token>

    Returns (FirebaseUser, token) on success, None if no header is present,
    or raises AuthenticationFailed for an invalid/expired token.
    """

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
    """Allows access only to requests with a verified Firebase identity."""

    def has_permission(self, request, view):
        return bool(request.user and getattr(request.user, 'is_authenticated', False))
