from rest_framework import serializers
from .models import (
    AdminStaffMember, Songs, Product, Users, Overseer, District, Community, 
    OverseerCommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch,  AdminStaffMember, AuditLog,EventContribution,EventDiary,
    TactsoCommitteeMember, ApplicationRequest,UserUniversityApplication,Community, District, Overseer
,SellerListing,Product, Order,OrderItem,ContributionHistory, MonthlyReport,IssueReport, Visitor)

class OrderItemSerializer(serializers.ModelSerializer):
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), 
        source='product'
    )

    class Meta:
        model = OrderItem
        fields = ['product_id', 'quantity', 'price', 'color', 'size']

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True)

    user_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(),
        slug_field='uid',  
        source='user',     
        write_only=True
    )

    class Meta:
        model = Order
        fields = [
            'id', 
            'user_uid', 
            'full_name', 'email', 'phone_number', 
            'address', 'city', 'postal_code', 'total_amount', 
            'status', 'is_paid', 'transaction_id', 'created_at', 'items'
        ]
        read_only_fields = ['created_at', 'updated_at', 'status', 'is_paid', 'transaction_id']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        
        order = Order.objects.create(**validated_data)

        for item_data in items_data:
            OrderItem.objects.create(
                order=order,
                **item_data 
            )

        return order
class ProductSerializer(serializers.ModelSerializer):
    image_url = serializers.URLField()
    additional_images = serializers.JSONField(required=False)
    
    class Meta:
        model = Product
        fields =  '__all__'

    def validate_additionalImages(self, value):
        if isinstance(value, list) and len(value) > 9:
            raise serializers.ValidationError("You can only have up to 10 images total (1 Main + 9 Additional).")
        return value

class SellerListingSerializer(serializers.ModelSerializer):
    product_name = serializers.ReadOnlyField(source='product.name')
    description = serializers.ReadOnlyField(source='product.description')
    image_url = serializers.ReadOnlyField(source='product.image_url') 
    category = serializers.ReadOnlyField(source='product.category')
    
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), 
        source='product',  
    )

    seller_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(),
        slug_field='uid',
        source='seller', 
    )

    class Meta:
        model = SellerListing
        fields = [
            'id', 
            'product_id',   
            'seller_uid',   
            'price', 
            'location', 
            'seller_colors', 
            'seller_sizes',
            'product_name', 
            'description', 
            'image_url',    
            'category', 
            'created_at'
        ]

class SongSerializer(serializers.ModelSerializer):
    class Meta:
        model = Songs
        fields = "__all__"

class UsersSerializer(serializers.ModelSerializer):
    overseer_name = serializers.SerializerMethodField()
    overseer_region = serializers.SerializerMethodField()

    class Meta:
        model = Users
        fields ="__all__"

    def get_overseer_name(self, obj):
        if obj.overseer_uid:
            overseer = Overseer.objects.filter(uid=obj.overseer_uid).first()
            if overseer:
                return overseer.overseer_initials_surname
        return "Not Assigned"

    def get_overseer_region(self, obj):
        if obj.overseer_uid:
            overseer = Overseer.objects.filter(uid=obj.overseer_uid).first()
            if overseer:
                return overseer.region
        return "Unknown Region"
class VisitorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Visitor
        fields = '__all__'
class UserUniversityApplicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserUniversityApplication
        fields = "__all__" 

class CommunitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Community
        fields = ['id', 'community_name', 'latitude', 'longitude', 'full_address','district_elder_name', 'district']
        read_only_fields = ['latitude', 'longitude']

class DistrictSerializer(serializers.ModelSerializer):
    communities = CommunitySerializer(many=True)
    overseer_uid = serializers.ReadOnlyField(source='overseer.uid')

    class Meta:
        model = District
        fields = [
            'id', 
            'district_elder_name', 
            'communities', 
            'overseer_uid' ,
            'overseer'
        ]

class OverseerSerializer(serializers.ModelSerializer):
    districts = DistrictSerializer(many=True)

    class Meta:
        model = Overseer
        fields = '__all__'

    def create(self, validated_data): 
        districts_data = validated_data.pop('districts')
         
        overseer = Overseer.objects.create(**validated_data)
 
        for district_data in districts_data:
            communities_data = district_data.pop('communities')
            district = District.objects.create(overseer=overseer, **district_data)
 
            for community_data in communities_data:
                Community.objects.create(district=district, **community_data)

        return overseer

class OverseerCommitteeMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = OverseerCommitteeMember
        fields = "__all__"

class IssueReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = IssueReport
        fields = "__all__"

class OverseerExpenseReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = OverseerExpenseReport
        fields = "__all__"

class UpcomingEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = UpcomingEvent
        fields = "__all__"

class CareerOpportunitySerializer(serializers.ModelSerializer):
    class Meta:
        model = CareerOpportunity
        fields = "__all__"

class TactsoBranchSerializer(serializers.ModelSerializer):
    class Meta:
        model = TactsoBranch
        fields = "__all__"
 
class TactsoCommitteeMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = TactsoCommitteeMember
        fields = "__all__"

class ApplicationRequestSerializer(serializers.ModelSerializer):
    branch_id = serializers.PrimaryKeyRelatedField(
        queryset=TactsoBranch.objects.all(), source='branch', write_only=True
    )
    user_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(), 
        slug_field='uid', 
        source='user', 
        write_only=True
    )

    university_name = serializers.ReadOnlyField(source='branch.university_name')
    
    class Meta:
        model = ApplicationRequest
        fields = '__all__'

class AdminStaffMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminStaffMember
        fields = "__all__"

class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = "__all__"

class ContributionHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ContributionHistory
        fields = '__all__'

class MonthlyReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = MonthlyReport
        fields = '__all__'
        
class EventContributionSerializer(serializers.ModelSerializer):
    overseer_name = serializers.ReadOnlyField(source='overseer.overseer_initials_surname')
    province = serializers.ReadOnlyField(source='overseer.province')
    region = serializers.ReadOnlyField(source='overseer.region')

    class Meta:
        model = EventContribution
        fields = ['id', 'event', 'overseer', 'overseer_name', 'province', 'region', 'amount', 'has_contributed', 'remarks', 'contribution_date']

class EventDiarySerializer(serializers.ModelSerializer):
    contributions = EventContributionSerializer(many=True, read_only=True)

    class Meta:
        model = EventDiary
        fields = ['id', 'title', 'day', 'month', 'year', 'is_active', 'contributions', 'created_at']
        
from .models import ApostolicGreeting

class ApostolicGreetingSerializer(serializers.ModelSerializer):
    class Meta:
        model = ApostolicGreeting
        fields = '__all__'