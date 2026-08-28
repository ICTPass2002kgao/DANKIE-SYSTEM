from django.core.cache import cache
from rest_framework.response import Response
import urllib.parse
class CachedListMixin:
    """
    A Mixin that caches list() actions dynamically based on query parameters.
    """
    cache_timeout = 60 * 60 * 24 * 30 

    def list(self, request, *args, **kwargs):
        qs = self.queryset if self.queryset is not None else self.get_queryset()
        model_name = qs.model.__name__
        
        # Build a unique cache key incorporating query parameters (like ?branch=ID)
        params_string = urllib.parse.urlencode(sorted(request.query_params.items()))
        cache_key = f"list_cache_{model_name}_{params_string}"

        # Check Redis
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data)

        # Fetch from DB
        response = super().list(request, *args, **kwargs)

        # Save to Redis
        cache.set(cache_key, response.data, timeout=self.cache_timeout)
        
        return response