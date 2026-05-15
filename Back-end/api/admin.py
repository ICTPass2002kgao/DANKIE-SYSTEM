from django.contrib import admin
from .models import (
    IssueReport, Songs, Product, Users, UserUniversityApplication,
    Overseer, District, Community, OverseerCommitteeMember,
    OverseerExpenseReport, UpcomingEvent,
    CareerOpportunity, TactsoBranch, TactsoCommitteeMember, ApplicationRequest,
    AdminStaffMember, AuditLog,
    SellerListing, Order, OrderItem,
    UsersHelp, ContributionHistory, MonthlyReport, Visitor
)

# ===========================
# 1. CORE CONTENT
# ===========================

@admin.register(Songs)
class SongsAdmin(admin.ModelAdmin):
    list_display = ('song_name', 'artist', 'category', 'released')
    search_fields = ('song_name', 'artist')


@admin.register(IssueReport)
class IssueReportAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'reported_at', 'is_resolved')
    search_fields = ('title', 'description')
    list_filter = ('reported_by', 'reported_at', 'is_resolved')


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'createdAt')
    search_fields = ('name', 'description')
    list_filter = ('category', 'createdAt')


# ===========================
# 2. USER & OVERSEER
# ===========================

@admin.register(Users)
class UsersAdmin(admin.ModelAdmin):
    list_display = ('email', 'role', 'province', 'account_verified', 'uid')
    search_fields = ('email', 'uid', 'surname', 'name')
    list_filter = ('role', 'province', 'account_verified')


@admin.register(Visitor)
class VisitorAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'community_name', 'visitor_category', 'ready_for_membership', 'last_attended_date')
    list_filter = ('visitor_category', 'ready_for_membership', 'gender', 'community_name')
    search_fields = ('name', 'surname', 'phone', 'community_name')


@admin.register(UserUniversityApplication)
class UserUniversityApplicationAdmin(admin.ModelAdmin):
    list_display = ('user', 'university_name', 'status', 'primary_program')
    search_fields = ('university_name', 'status', 'user__email')


class DistrictInline(admin.TabularInline):
    model = District
    extra = 0


@admin.register(Overseer)
class OverseerAdmin(admin.ModelAdmin):
    list_display = ('overseer_initials_surname', 'code', 'province', 'region')
    search_fields = ('overseer_initials_surname', 'email', 'code')
    inlines = [DistrictInline]


class CommunityInline(admin.TabularInline):
    model = Community
    extra = 0


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ('district_elder_name', 'overseer')
    search_fields = ('district_elder_name', 'overseer__overseer_initials_surname')
    inlines = [CommunityInline]


@admin.register(Community)
class CommunityAdmin(admin.ModelAdmin):
    list_display = ('community_name', 'district', 'full_address', 'latitude', 'longitude')
    search_fields = ('community_name', 'full_address')


@admin.register(OverseerCommitteeMember)
class OverseerCommitteeMemberAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'portfolio', 'overseer')
    search_fields = ('full_name', 'portfolio')


# ===========================
# 3. FINANCIAL & EVENTS
# ===========================

@admin.register(OverseerExpenseReport)
class OverseerExpenseReportAdmin(admin.ModelAdmin):
    list_display = ('community_name', 'month', 'year', 'total_banked', 'total_expenses')
    list_filter = ('month', 'year', 'province')
    search_fields = ('community_name', 'overseer_uid')


@admin.register(UpcomingEvent)
class UpcomingEventAdmin(admin.ModelAdmin):
    list_display = ('title', 'day', 'month', 'created_at')
    search_fields = ('title',)


# ===========================
# 4. CAREERS & EDUCATION
# ===========================

@admin.register(CareerOpportunity)
class CareerOpportunityAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'expiry_date', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('title', 'description')


@admin.register(TactsoCommitteeMember)
class TactsoCommitteeMemberAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'portfolio', 'branch')
    search_fields = ('full_name', 'branch__university_name')


@admin.register(ApplicationRequest)
class ApplicationRequestAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'branch', 'status', 'primary_program')
    list_filter = ('status',)
    search_fields = ('full_name', 'email', 'branch__university_name')


@admin.register(TactsoBranch)
class TactsoBranchAdmin(admin.ModelAdmin):
    list_display = ('university_name', 'overseer', 'assigned_district', 'is_application_open')
    list_filter = ('overseer', 'is_application_open')
    search_fields = ('university_name', 'email')

    fieldsets = (
        ('University Info', {
            'fields': ('uid', 'university_name', 'email', 'address', 'application_link')
        }),
        ('Leadership Assignment', {
            'description': "Assign an Overseer and a specific District.",
            'fields': ('overseer', 'assigned_district')
        }),
        ('Status & Media', {
            'fields': ('is_application_open', 'image_url', 'has_multiple_campuses')
        }),
        ('Officers', {
            'fields': ('education_officer_name', 'education_officer_email',
                       'education_officer_face_url', 'chairperson_email')
        }),
    )


# ===========================
# 5. STAFF & LOGS
# ===========================

@admin.register(AdminStaffMember)
class AdminStaffMemberAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'role', 'email', 'is_active')
    list_filter = ('role', 'is_active')
    search_fields = ('full_name', 'email')


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('action', 'actor_name', 'timestamp', 'university_name')
    list_filter = ('action', 'actor_role')
    search_fields = ('actor_name', 'details', 'uid')


# ===========================
# 6. MARKETPLACE
# ===========================

@admin.register(SellerListing)
class SellerListingAdmin(admin.ModelAdmin):
    list_display = ('product', 'seller', 'price', 'location', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('product__name', 'seller__email', 'location')
    autocomplete_fields = ['product', 'seller']


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('product', 'price', 'quantity', 'get_cost')

    def get_cost(self, obj):
        return obj.get_cost()

    get_cost.short_description = "Cost"


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'email', 'total_amount', 'status', 'is_paid', 'created_at', 'get_items')
    list_filter = ('status', 'is_paid', 'created_at')
    search_fields = ('id', 'email', 'full_name', 'transaction_id')
    inlines = [OrderItemInline]
    readonly_fields = ('created_at', 'updated_at', 'transaction_id', 'paystack_transaction_data')

    def get_items(self, obj):
        return ", ".join([item.product.name for item in obj.items.all()])

    get_items.short_description = "Items"


# ===========================
# 7. SUPPORTING MODELS
# ===========================

@admin.register(UsersHelp)
class UsersHelpAdmin(admin.ModelAdmin):
    list_display = ('user_email', 'subject', 'status', 'time_stamp')
    search_fields = ('user_email', 'subject')
    list_filter = ('status',)


@admin.register(ContributionHistory)
class ContributionHistoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'community', 'month', 'year')
    list_filter = ('month', 'year')
    search_fields = ('name', 'surname', 'community')


@admin.register(MonthlyReport)
class MonthlyReportAdmin(admin.ModelAdmin):
    list_display = ('community_name', 'month', 'year')
    list_filter = ('month', 'year')
    search_fields = ('community_name',)