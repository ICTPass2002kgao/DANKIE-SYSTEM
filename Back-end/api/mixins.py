from django.core.cache import cache
from rest_framework.response import Response

class CachedListMixin:
    """
    A Mixin that provides 'Cache Forever, Clear on Update' logic for the list() action.
    """
    # Default cache timeout (30 days)
    cache_timeout = 60 * 60 * 24 * 30 

    def list(self, request, *args, **kwargs):
        # 1. Get the Model Name (e.g., "Songs", "Product")
        # Try to get queryset property, if None, call get_queryset()
        qs = self.queryset if self.queryset is not None else self.get_queryset()
        model_name = qs.model.__name__
        cache_key = f"list_cache_{model_name}"

        # 2. SAFETY CHECK: If the user is filtering (using query params), SKIP CACHE.
        # Example: ?face_url=... or ?email=...
        # We don't want to return the "All Users" cache when they asked for "One User".
        if request.query_params:
            return super().list(request, *args, **kwargs)

        # 3. Check Redis
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data)

        # 4. Fetch from DB (The Slow Part)
        response = super().list(request, *args, **kwargs)

        # 5. Save to Redis
        cache.set(cache_key, response.data, timeout=self.cache_timeout)
        
        return response