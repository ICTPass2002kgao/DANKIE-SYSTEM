from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.core.cache import cache
from .models import (
    Songs, Product, Users, Overseer, District, Community, 
    OverseerCommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch,   AdminStaffMember, AuditLog,
    TactsoCommitteeMember, ApplicationRequest, UserUniversityApplication
)

# List of all models we want to auto-clean
ALL_MODELS = [
    Songs, Product, Users, Overseer, District, Community, 
    OverseerCommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch,   AdminStaffMember, AuditLog,
    TactsoCommitteeMember, ApplicationRequest, UserUniversityApplication
]

def clear_model_cache(sender, instance, **kwargs):
    """
    Deletes the specific cache key for the model that was just changed.
    """
    model_name = sender.__name__
    cache_key = f"list_cache_{model_name}"
    
    # Check if key exists before trying to delete (optional optimization)
    if cache.get(cache_key):
        print(f"🧹 Data changed in {model_name}. Clearing cache key: {cache_key}")
        cache.delete(cache_key)

# Register the signal for every model in the list
for model in ALL_MODELS:
    post_save.connect(clear_model_cache, sender=model)
    post_delete.connect(clear_model_cache, sender=model)