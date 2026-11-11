from django.core.management.base import BaseCommand
from django.core.cache import cache


class Command(BaseCommand):
    help = "Clear all Redis caches (stale list responses, etc.)"

    def handle(self, *args, **options):
        cache.clear()
        self.stdout.write(
            self.style.SUCCESS("✅ All Redis caches cleared successfully.")
        )
