from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

# This file routes traffic to the correct app
urlpatterns = [
    path('admin/', admin.site.urls),
    # This line tells Django: "Any URL starting with 'api/' goes to api/urls.py"
    path('api/', include('api.urls')), 
]

# Add media URL handling for development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)