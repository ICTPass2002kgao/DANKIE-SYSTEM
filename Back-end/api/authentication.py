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
    """
    Allows access to any verified Firebase identity — including anonymous users.
    Use this only on endpoints that must be reachable before account creation
    (e.g. browsing overseers during registration).
    """

    def has_permission(self, request, view):
        return bool(request.user and getattr(request.user, 'is_authenticated', False))


class IsFullyAuthenticated(BasePermission):
    """
    Requires a verified Firebase identity that is NOT anonymous.

    This is the default permission for all protected endpoints. It blocks:
    - Unauthenticated requests (no token)
    - Anonymous Firebase sessions (sign_in_provider == 'anonymous')

    Only users who have created a real email/password (or other non-anonymous)
    Firebase account can pass this check.
    """

    def has_permission(self, request, view):
        if not request.user or not getattr(request.user, 'is_authenticated', False):
            return False
        decoded = getattr(request.user, 'decoded_token', {})
        sign_in_provider = decoded.get('firebase', {}).get('sign_in_provider', '')
        return sign_in_provider != 'anonymous'
