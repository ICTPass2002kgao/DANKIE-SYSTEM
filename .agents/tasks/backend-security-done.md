# Backend Security Implementation — Verification Summary

## settings.py Changes

1. **REST_FRAMEWORK block added** — global defaults now enforce `FirebaseAuthentication` and `IsFirebaseAuthenticated` on every endpoint.
2. **DEBUG default changed to `'False'`** — production-safe: `os.environ.get('DJANGO_DEBUG', 'False') == 'True'`
3. **SECRET_KEY hardened** — now raises `ValueError` if `SECRET_KEY` env var is not set (no fallback to random key).
4. **EMAIL_HOST_PASSWORD moved to env var** — `os.environ.get('EMAIL_HOST_PASSWORD', '')` replaces the hardcoded App Password.
5. **CORS_ALLOW_ALL_ORIGINS set to `False`** — replaced with explicit `CORS_ALLOWED_ORIGINS` list containing `mktechcloud.co.za` (the real domain found in ALLOWED_HOSTS/CSRF_TRUSTED_ORIGINS).
6. **No `'*'` was present in ALLOWED_HOSTS** — no removal needed; all entries were real domains.

## ViewSets Fixed (api/views.py)

| ViewSet / View | Change |
|---|---|
| `ServeDecryptedImageView` | Removed `authentication_classes = []` and `permission_classes = []`; global defaults now apply |
| `TactsoBranchViewSet` | Added `authentication_classes = [FirebaseAuthentication]` and `permission_classes = [IsFirebaseAuthenticated]` |
| `send_email` FBV | Added `@authentication_classes([FirebaseAuthentication])` and `@permission_classes([IsFirebaseAuthenticated])` decorators |
| `OrderViewSet.verify_payment` | Changed from `authentication_classes=[], permission_classes=[AllowAny]` to `FirebaseAuthentication` / `IsFirebaseAuthenticated` |
| `UsersViewSet` | Removed `get_permissions`/`get_authenticators` conditionals; class-level auth/permission now enforced for ALL methods |
| `OverseerViewSet` | Removed `get_permissions`/`get_authenticators` conditionals; class-level auth/permission now enforced for ALL methods |
| `DistrictViewSet` | Removed `get_permissions`/`get_authenticators` conditionals; class-level auth/permission now enforced for ALL methods |
| `CommunityViewSet` | Removed `get_permissions`/`get_authenticators` conditionals; class-level auth/permission now enforced for ALL methods |

## Serializers with write_only Fields (api/serializers.py)

| Serializer | write_only Fields Added |
|---|---|
| `OverseerSerializer` | `paystack_auth_code`, `paystack_email` |
| `OverseerCommitteeMemberSerializer` | `face_encorded_json` |
| `TactsoCommitteeMemberSerializer` | `face_encorded_json` |
| `AdminStaffMemberSerializer` | `face_encorded_json` |

## requirements.txt

`firebase_admin==7.2.0` was **already present** — no changes made.
