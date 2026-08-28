import urllib.parse
from django.core.cache import cache
from rest_framework.response import Response

class CachedListMixin:
    cache_timeout = 60 * 60 * 24 * 30 

    def list(self, request, *args, **kwargs):
        print("🟢 CachedListMixin.list() was CALLED!") # Check if this appears in Railway logs
        
        qs = self.queryset if self.queryset is not None else self.get_queryset()
        model_name = qs.model.__name__
        
        params_string = urllib.parse.urlencode(sorted(request.query_params.items()))
        cache_key = f"list_cache_{model_name}_{params_string}"
        print(f"🔑 Generated Cache Key: {cache_key}")

        # Check Redis
        cached_data = cache.get(cache_key)
        if cached_data:
            print("🚀 CACHE HIT! Serving from Redis.")
            return Response(cached_data)

        print("🐢 CACHE MISS. Fetching from database...")
        response = super().list(request, *args, **kwargs)

        # Save to Redis
        cache.set(cache_key, response.data, timeout=self.cache_timeout)
        print("💾 Saved response data to Redis successfully.")
        
        return response