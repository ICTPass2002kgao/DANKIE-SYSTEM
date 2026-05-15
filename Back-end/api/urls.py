
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ApostolicGreetingViewSet, SongViewSet, UsersViewSet, OverseerViewSet,
    DistrictViewSet, CommunityViewSet, OverseerCommitteeMemberViewSet,
    OverseerExpenseReportViewSet, UpcomingEventViewSet,
    CareerOpportunityViewSet, TactsoBranchViewSet,  
    StaffMemberViewSet, AuditLogViewSet, BranchCommitteeMemberViewSet,
    ApplicationRequestViewSet, UserUniversityApplicationViewSet,
    recognize_face, send_legal_broadcast,ServeDecryptedImageView,
    CatalogViewSet, 
    SellerInventoryViewSet, 
    OrderViewSet,
    initialize_subscription,
    create_seller_subaccount,
    create_payment_link,
    paystack_webhook,
    send_custom_email,
    ContributionHistoryViewSet
    ,MonthlyReportViewSet,VisitorViewSet,EventDiaryViewSet,EventContributionViewSet
) 
from . import views 
# Initialize Router
router = DefaultRouter()  

router.register(r'products', CatalogViewSet, basename='products')
router.register(r'seller-inventory', SellerInventoryViewSet, basename='seller-inventory')
router.register(r'orders', OrderViewSet, basename='orders')
router.register(r'issue_report', views.IssueReportViewSet, basename='issue_report')
router.register(r'staff', StaffMemberViewSet)
router.register(r'overseers', OverseerViewSet)
router.register(r'tactso_branches', TactsoBranchViewSet) 
router.register(r'users', UsersViewSet) 
router.register(r'communities', CommunityViewSet) 
router.register(r'songs', SongViewSet) 
router.register(r'districts', DistrictViewSet)
router.register(r'committee_members', OverseerCommitteeMemberViewSet, basename='committee-members')
router.register(r'overseer_expenses_reports', OverseerExpenseReportViewSet,basename='overseer-expenses')
router.register(r'events', UpcomingEventViewSet)
router.register(r'careers', CareerOpportunityViewSet) 
router.register(r'branch_committee', BranchCommitteeMemberViewSet)
router.register(r'applications', ApplicationRequestViewSet)
router.register(r'university_applications', UserUniversityApplicationViewSet)
router.register(r'audit_logs', AuditLogViewSet)
router.register(r'contribution_history', ContributionHistoryViewSet)
router.register(r'monthly_reports', MonthlyReportViewSet)
router.register(r'visitors', VisitorViewSet, basename='visitors')
# Add to your router
router.register(r'event_diary', EventDiaryViewSet, basename='event_diary')
router.register(r'apostolic_greetings', ApostolicGreetingViewSet, basename='apostolic_greetings')
router.register(r'event_contributions', EventContributionViewSet, basename='event_contributions')

urlpatterns = [ 
    path('', include(router.urls)), 
    path('verify_faces/', recognize_face, name='verify_faces'),  
    path('send-email/', send_legal_broadcast, name='send_email'),
    path('serve_image/', ServeDecryptedImageView.as_view(), name='serve_image'), 
    path('initialize-subscription/', initialize_subscription), 
    
    # Marketplace
    path('create_seller_subaccount/', create_seller_subaccount),
    path('create-payment-link/', create_payment_link),
    path('paystack-webhook/', paystack_webhook),
    # Add this to your urlpatterns in urls.py
    path('monthly_attendance_report/', views.monthly_attendance_report, name='monthly_attendance_report'),
    
    # Utilities
    path('send_custom_email/', send_custom_email), 
]
