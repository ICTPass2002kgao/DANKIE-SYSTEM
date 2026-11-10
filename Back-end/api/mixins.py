import urllib.parse
from django.core.cache import cache
from django.db.models import Model
from rest_framework.response import Response


class CachedListMixin:
    cache_timeout = 60 * 5  # 5 minutes (was 30 days — way too long)

    def _cache_prefix(self):
        """Return the cache key prefix for this model."""
        qs = self.queryset if self.queryset is not None else self.get_queryset()
        return f"list_cache_{qs.model.__name__}"

    def _invalidate_cache(self):
        """Delete all cached list responses for this model."""
        prefix = self._cache_prefix()
        # django-redis exposes delete_pattern; fall back gracefully if not available
        try:
            cache.delete_pattern(f"{prefix}*")
        except AttributeError:
            # Fallback: iterate known keys (less efficient but works without django-redis)
            # This is a best-effort cleanup for non-Redis backends
            pass

    def list(self, request, *args, **kwargs):
        qs = self.queryset if self.queryset is not None else self.get_queryset()
        model_name = qs.model.__name__

        params_string = urllib.parse.urlencode(sorted(request.query_params.items()))
        cache_key = f"list_cache_{model_name}_{params_string}"

        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data)

        response = super().list(request, *args, **kwargs)
        cache.set(cache_key, response.data, timeout=self.cache_timeout)
        return response

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        self._invalidate_cache()
        return response

    def update(self, request, *args, **kwargs):
        response = super().update(request, *args, **kwargs)
        self._invalidate_cache()
        return response

    def partial_update(self, request, *args, **kwargs):
        response = super().partial_update(request, *args, **kwargs)
        self._invalidate_cache()
        return response

    def destroy(self, request, *args, **kwargs):
        response = super().destroy(request, *args, **kwargs)
        self._invalidate_cache()
        return response