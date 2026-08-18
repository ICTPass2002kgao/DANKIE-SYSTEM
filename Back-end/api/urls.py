
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
    ContributionHistoryViewSet
    ,MonthlyReportViewSet,
    VisitorViewSet,
    EventDiaryViewSet,
    EventContributionViewSet,
    global_attendance_summary,user_attendance,OverseerDiaryEventViewSet,
    OverseerMeetingMinutesViewSet,
    OverseerCommunicationViewSet,
    CommunicationReadStatusViewSet
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
router.register(r'overseer_diary_events', OverseerDiaryEventViewSet, basename='overseer-diary-events') 
router.register(r'overseer_communications', OverseerCommunicationViewSet, basename='overseer-communications')
router.register(r'communication_read_statuses', CommunicationReadStatusViewSet, basename='communication-read-statuses')
router.register(r'branch_committee', BranchCommitteeMemberViewSet)
router.register(r'applications', ApplicationRequestViewSet)
router.register(r'university_applications', UserUniversityApplicationViewSet)
router.register(r'audit_logs', AuditLogViewSet)
router.register(r'contribution_history', ContributionHistoryViewSet)
router.register(r'monthly_reports', MonthlyReportViewSet)
router.register(r'visitors', VisitorViewSet, basename='visitors')
router.register(r'tactso_meeting_minutes', views.TactsoMeetingMinutesViewSet, basename='tactso-meeting-minutes')
# Add to your router
router.register(r'event_diary', EventDiaryViewSet, basename='event_diary')
router.register(r'apostolic_greetings', ApostolicGreetingViewSet, basename='apostolic_greetings')
router.register(r'event_contributions', EventContributionViewSet, basename='event_contributions') 
router.register(r'overseer_meeting_minutes', OverseerMeetingMinutesViewSet, basename='overseer-meeting-minutes')

urlpatterns = [ 
    path('', include(router.urls)), 
    path('livekit-token/', views.generate_livekit_token),
    path('tactso-livekit-token/', views.generate_tactso_livekit_token),
    path('verify_faces/', recognize_face, name='verify_faces'),  
    path('send-email-broadcast/', send_legal_broadcast, name='send_email'),
    path('serve_image/', ServeDecryptedImageView.as_view(), name='serve_image'), 
    path('initialize-subscription/', initialize_subscription), 
    path('global_attendance_summary/', global_attendance_summary, name='global_attendance_summary'),
    path('user_attendance/', user_attendance, name='user_attendance'),
    path('create_seller_subaccount/', create_seller_subaccount),
    path('create-payment-link/', create_payment_link),
    path('paystack-webhook/', paystack_webhook),
    path('send-email/', views.send_email, name='send-email'),
    path('monthly_attendance_report/', views.monthly_attendance_report, name='monthly_attendance_report'),
    
     
]