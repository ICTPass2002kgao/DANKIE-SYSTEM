import uuid
from django.db import models
from django.utils import timezone
from geopy.geocoders import Nominatim 

GENDER_CHOICES = (
    ('Male', 'Male'),
    ('Female', 'Female'),
)

MEMBER_TYPE_CHOICES = (
    ('Member', 'Member'),
    ('Testify', 'Testify'),
)

ARTIST_TYPE_CHOICES = (
    ('Overseer', 'Overseer Chairperson'),
    ('Tactso', 'Tactso Chairperson'),
)

# ===============================================================================================
# 1. CORE CONTENT MODELS
# ===============================================================================================

class Songs(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    artist = models.CharField(max_length=255, verbose_name="Artist", blank=False)
    artist_type = models.CharField(max_length=50, choices=ARTIST_TYPE_CHOICES, blank=True, null=True, verbose_name="Artist Type")
    category = models.CharField(max_length=255, verbose_name="Category", blank=False)
    released = models.CharField(max_length=255, null=True, blank=True, verbose_name="Released Date")
    song_url = models.TextField(verbose_name="Song url", blank=False)
    song_name = models.CharField(max_length=255, verbose_name="Song Name", blank=False)
    
    # Contract & Visibility Workflow
    signature = models.TextField(verbose_name="Signature", blank=True, null=True)
    contract_signed = models.BooleanField(default=False, verbose_name="Contract Signed")
    is_visible = models.BooleanField(default=False, verbose_name="Is Visible")
    
    # Links directly to the Committee members, restricted ONLY to Chairpersons
     
    
    def __str__(self):
        return self.song_name
  
class Product(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, verbose_name="Product Name", null=True, blank=True)
    description = models.TextField(verbose_name="Product Description", blank=False)
    category = models.CharField(max_length=255, verbose_name="Category", blank=False)
    createdAt = models.DateTimeField(default=timezone.now, verbose_name="Created At")
    image_url = models.TextField(verbose_name="Main Image URL", blank=True) 
    additional_images = models.JSONField(default=list, blank=True, verbose_name="Gallery Images")
    all_available_colors = models.JSONField(default=list, blank=True) 
    all_available_sizes = models.JSONField(default=list, blank=True)

    def __str__(self):
        return self.name if self.name else "Unnamed Product"
    
  
class Users(models.Model): 
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uid = models.CharField(max_length=255, unique=True, db_index=True) 
    email = models.EmailField(max_length=255, blank=True, null=True)
    phone = models.CharField(max_length=100, blank=True, null=True)
    name = models.CharField(max_length=255, blank=True)
    surname = models.CharField(max_length=255, blank=True, null=True)
    address = models.CharField(max_length=500, blank=True, null=True) 
    province = models.CharField(max_length=255, blank=True, null=True) 
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True) 
    last_attended_date = models.DateField(auto_now_add=True, null=True, blank=True) 
    seller_paystack_account = models.CharField(max_length=255, blank=True, null=True)
    account_verified = models.BooleanField(default=False) 
    role = models.CharField(max_length=255, blank=True, null=True)
    community_name = models.CharField(max_length=255, blank=True, null=True)
    district_elder_name = models.CharField(max_length=255, blank=True, null=True)
    overseer_uid = models.CharField(max_length=255, blank=True, null=True) 
    profile_url = models.TextField(blank=True, null=True)   
    
    verification_status = models.CharField(max_length=50, default='Unverified', blank=True, null=True)
    contract_signature_url = models.TextField(blank=True, null=True)
    id_document_url = models.TextField(blank=True, null=True)
    face_image_url = models.TextField(blank=True, null=True)
    
    week1 = models.CharField(max_length=255, blank=True, null=True)
    week2 = models.CharField(max_length=255, blank=True, null=True)
    week3 = models.CharField(max_length=255, blank=True, null=True)
    week4 = models.CharField(max_length=255, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.email} ({self.role})"
        
class Visitor(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    community_name = models.CharField(max_length=255, verbose_name="Church/Branch Name")
    name = models.CharField(max_length=255)
    overseer_uid = models.CharField(max_length=255, blank=True, null=True)
    district_elder_name = models.CharField(max_length=255, blank=True, null=True)
    surname = models.CharField(max_length=255)
    phone = models.CharField(max_length=100, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES)
    visitor_category = models.CharField(max_length=255, default='Testify')
    visitor_role = models.CharField(max_length=255, blank=True, null=True)
    ready_for_membership = models.BooleanField(default=False)
    last_attended_date = models.DateField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Visitor: {self.name} {self.surname}"
    
class SellerListing(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    product = models.ForeignKey('Product', on_delete=models.CASCADE, related_name='listings')
    seller = models.ForeignKey(
        Users, 
        to_field='uid', 
        on_delete=models.CASCADE, 
        related_name='seller_listings',
        db_column='seller_uid' 
    )
    price = models.DecimalField(max_digits=10, decimal_places=2)
    location = models.CharField(max_length=255)
    seller_colors = models.JSONField(default=list) 
    seller_sizes = models.JSONField(default=list)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'seller') 

    def __str__(self):
        return f"{self.product.name} - {self.seller.uid}"

class Order(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    user = models.ForeignKey(
        Users, 
        on_delete=models.CASCADE, 
        to_field='uid', 
        db_column='user_uid',
        related_name='orders'
    )
    
    full_name = models.CharField(max_length=255)
    email = models.EmailField()
    phone_number = models.CharField(max_length=100) 
    address = models.TextField()
    city = models.CharField(max_length=255)
    postal_code = models.CharField(max_length=100) 
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=100, choices=STATUS_CHOICES, default='pending') 
    is_paid = models.BooleanField(default=False)
    transaction_id = models.CharField(max_length=255, blank=True, null=True)
    paystack_transaction_data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Order {self.id} - {self.user} - {self.status}"

class OrderItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order = models.ForeignKey(Order, related_name='items', on_delete=models.CASCADE)
    product = models.ForeignKey('Product', on_delete=models.PROTECT) 
    price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.PositiveIntegerField(default=1)
    color = models.CharField(max_length=255)
    size = models.CharField(max_length=255)

    def __str__(self):
        return f"{self.quantity} x {self.product} in Order {self.order.id}"

    def get_cost(self):
        return self.price * self.quantity

class UserUniversityApplication(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(Users, related_name="university_applications", on_delete=models.CASCADE)
    application_uid = models.CharField(max_length=255, verbose_name="Application UID")
    university_name = models.CharField(max_length=255, verbose_name="University Name")
    campus_name = models.CharField(max_length=255, blank=True, verbose_name="Campus Name")
    status = models.CharField(max_length=255, verbose_name="Status")
    submission_date = models.TextField(blank=True, verbose_name="Submission Date")
    primary_program = models.CharField(max_length=255, blank=True, verbose_name="Primary Program")
    second_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Second Choice Program")
    third_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Third Choice Program")
    applying_for_funding = models.BooleanField(default=False, verbose_name="Funding")
    applying_for_residence = models.BooleanField(default=False, verbose_name="Residence")
    full_name = models.CharField(max_length=255, blank=True, verbose_name="Full Name")
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True)
    email = models.EmailField(blank=True, verbose_name="Email")
    phone = models.CharField(max_length=100, blank=True, verbose_name="Phone")
    highest_qualification = models.CharField(max_length=255, blank=True, verbose_name="Highest Qualification")
    previous_school = models.CharField(max_length=255, blank=True, verbose_name="Previous School")

    def __str__(self):
        return f"{self.university_name} - {self.status}"
 
# ===============================================================================================
# 2. USER & OVERSEER MODELS
# ===============================================================================================

class Overseer(models.Model): 
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uid = models.TextField(null=False, unique=True,blank=False)
    overseer_initials_surname = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    province = models.CharField(max_length=255)
    region = models.CharField(max_length=255)
    code = models.CharField(max_length=255) 
    paystack_auth_code = models.CharField(max_length=255,blank=True)
    subscription_status = models.CharField(max_length=255,default='inactive') 
    last_charged=models.DateField(auto_now=True) 
    last_charged_amount = models.DecimalField( decimal_places=2,max_digits=10,blank=True,null=True)
    current_member_count = models.IntegerField(default=0) 
    next_charge_date = models.CharField(max_length=255, blank=True) 
    current_plan = models.CharField(max_length=255, blank=True, null=True, default='free_tier')
    has_agreed_to_terms = models.BooleanField(default=False)
    has_agreed_to_privacy_policy = models.BooleanField(default=False)
    def __str__(self):
        return self.overseer_initials_surname

class OverseerCommitteeMember(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    overseer = models.ForeignKey(Overseer, related_name="committee_members", on_delete=models.CASCADE)
    full_name = models.CharField(max_length=255, verbose_name="Full Name")
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True)
    email = models.EmailField(blank=True, verbose_name="Email") 
    accepted_ts_and_cs = models.BooleanField(default=False)
    portfolio = models.CharField(max_length=255, verbose_name="Portfolio")
    face_url = models.TextField(blank=True, verbose_name="Face URL")
    added_at = models.TextField(blank=True, verbose_name="Added At")

    def __str__(self):
        return f"{self.full_name} - {self.portfolio}"

class District(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    overseer = models.ForeignKey(Overseer, related_name='districts', on_delete=models.CASCADE)
    district_elder_name = models.CharField(max_length=255)

    def __str__(self):
        return f"{self.district_elder_name} ({self.overseer})"
 
class Community(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    district = models.ForeignKey(District, related_name='communities', on_delete=models.CASCADE)
    district_elder_name = models.TextField(max_length=255, blank=True, null=True)
    community_name = models.CharField(max_length=255)
    full_address = models.TextField(blank=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)

    def save(self, *args, **kwargs):
        overseer = self.district.overseer
        address_attempts = [
            f"{self.community_name}, {overseer.region}, {overseer.province}, South Africa",
            f"{self.community_name}, {overseer.province}, South Africa",
            f"{self.community_name}, South Africa",
            f"{overseer.region}, {overseer.province}, South Africa"
        ]
        self.full_address = address_attempts[0]

        if not self.latitude or not self.longitude:
            geolocator = Nominatim(user_agent="tact_backend_v2_smart_search")
            for address in address_attempts:
                try:
                    location = geolocator.geocode(address, timeout=10)
                    if location:
                        self.latitude = location.latitude
                        self.longitude = location.longitude
                        self.full_address = address 
                        break 
                except Exception as e:
                    continue 
 
        super(Community, self).save(*args, **kwargs)

    def __str__(self):
        return self.community_name

# ===============================================================================================
# 3. FINANCIAL & EVENTS
# ===============================================================================================

class OverseerExpenseReport(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    archived_at = models.TextField(verbose_name="Archived At", blank=True, null=True)
    overseer_uid = models.CharField(max_length=255, verbose_name="Overseer UID")
    district_elder_name = models.CharField(max_length=255, verbose_name="District Elder Name")
    community_name = models.CharField(max_length=255, verbose_name="Community Name")
    province = models.CharField(max_length=255, verbose_name="Province")
    expense_central = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Central")
    expense_other = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Other")
    expense_rent = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Rent")
    expense_mine = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Mine")
    total_banked = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Banked")
    total_expenses = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Expenses")
    total_income = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Income")
    month = models.IntegerField(verbose_name="Month")
    year = models.IntegerField(verbose_name="Year")

    def __str__(self):
        return f"Report: {self.community_name} ({self.month}/{self.year})"

class UpcomingEvent(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255, verbose_name="Title")
    poster_url = models.TextField(blank=True, verbose_name="Poster URL")
    day = models.CharField(max_length=255, verbose_name="Day") 
    month = models.CharField(max_length=255, verbose_name="Month")
    parsed_date = models.TextField(blank=True, verbose_name="Parsed Date", null=True) 
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return self.title

# ===============================================================================================
# 4. CAREERS & EDUCATION
# ===============================================================================================

class CareerOpportunity(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255, verbose_name="Title")
    description = models.TextField(verbose_name="Description")
    category = models.CharField(max_length=255, verbose_name="Category")
    application_email = models.EmailField(max_length=255, verbose_name="Application Email")
    contact_number = models.CharField(max_length=100, blank=True, verbose_name="Contact Number")
    is_active = models.BooleanField(default=True, verbose_name="Is Active")
    expiry_date = models.TextField(blank=True, verbose_name="Expiry Date", null=True)
    created_at = models.TextField(blank=True, verbose_name="Created At")
    updated_at = models.TextField(blank=True, null=True, verbose_name="Updated At")
    image_url = models.TextField(blank=True, verbose_name="Image URL")
    link = models.TextField(blank=True, verbose_name="External Link")
    details_address = models.TextField(blank=True, verbose_name="Details Address")
    course_duration = models.CharField(max_length=255, blank=True, verbose_name="Course Duration")
    duties_financial = models.TextField(blank=True, verbose_name="Duties Financial")
    duties_location = models.CharField(max_length=255, blank=True, verbose_name="Duties Location")
    requirements_subtitle = models.TextField(blank=True, verbose_name="Requirements Subtitle")
    benefits = models.TextField(blank=True, default="[]", verbose_name="Benefits (JSON)")
    required_documents = models.TextField(blank=True, default="[]", verbose_name="Required Documents (JSON)")

    def __str__(self):
        return self.title

class TactsoBranch(models.Model): 
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uid = models.CharField(max_length=255, unique=True, verbose_name="UID")
    university_name = models.CharField(max_length=255, verbose_name="University Name")
    overseer = models.ForeignKey(
        Overseer, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="managed_universities"
    )
    assigned_district = models.ForeignKey(
        District, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="university_branches"
    )
    email = models.EmailField(blank=True, verbose_name="Email")
    address = models.TextField(blank=True, verbose_name="Address")
    application_link = models.TextField(blank=True, verbose_name="Application Link")
    education_officer_email = models.EmailField(blank=True, verbose_name="Email")
    chairperson_email = models.EmailField(blank=True, verbose_name="Email") 
    image_url = models.TextField(blank=True, verbose_name="Image URLs (JSON)")
    education_officer_name = models.CharField(max_length=255, blank=True, verbose_name="Education Officer Name")
    education_officer_face_url = models.TextField(blank=True, verbose_name="Education Officer Face URL")
    authorized_user_face_urls = models.TextField(blank=True, default="[]", verbose_name="Authorized Face URLs (JSON)")
    has_multiple_campuses = models.BooleanField(default=False, verbose_name="Has Multiple Campuses")
    is_application_open = models.BooleanField(default=False, verbose_name="Is Application Open")
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return self.university_name

class ApplicationRequest(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    branch = models.ForeignKey(TactsoBranch, related_name="applications", on_delete=models.CASCADE, null=True, blank=True)
    user = models.ForeignKey('Users', related_name="my_applications", on_delete=models.CASCADE, to_field='uid', db_column='user_uid', null=True, blank=True)
    uid = models.CharField(max_length=255, verbose_name="Application UID")
    status = models.CharField(max_length=255, default="New", verbose_name="Status")
    submission_date = models.DateTimeField(auto_now_add=True, verbose_name="Submission Date")
    full_name = models.CharField(max_length=255, verbose_name="Full Name")
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True)
    email = models.EmailField(blank=True, verbose_name="Email")
    phone = models.CharField(max_length=100, blank=True, verbose_name="Phone")
    campus = models.CharField(max_length=255, blank=True, verbose_name="Campus", null=True)
    primary_program = models.CharField(max_length=255, blank=True, verbose_name="Primary Program")
    second_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Second Choice")
    third_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Third Choice")
    highest_qualification = models.CharField(max_length=255, blank=True, verbose_name="Qualification")
    previous_school = models.CharField(max_length=255, blank=True, verbose_name="Previous School")
    applying_for_funding = models.BooleanField(default=False, verbose_name="Funding")
    applying_for_residence = models.BooleanField(default=False, verbose_name="Residence")
    id_passport_url = models.TextField(blank=True, verbose_name="ID/Passport URL")
    school_results_url = models.TextField(blank=True, verbose_name="School Results URL")
    proof_of_registration_url = models.TextField(blank=True, verbose_name="Proof of Reg URL")
    other_qualifications_url = models.TextField(blank=True, verbose_name="Other Docs URL")

    def __str__(self):
        uni_name = self.branch.university_name if self.branch else "No University"
        return f"{self.full_name} -> {uni_name}"

class TactsoCommitteeMember(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    branch = models.ForeignKey(TactsoBranch, related_name="branch_committee_members", on_delete=models.CASCADE)
    accepted_ts_and_cs = models.BooleanField(default=False)
    full_name = models.CharField(max_length=255, verbose_name="Name")
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True)
    email = models.EmailField(blank=True, verbose_name="Email")
    portfolio = models.CharField(max_length=255, verbose_name="Portfolio")
    accepted_ts_and_cs = models.BooleanField(default=False)
    face_url = models.TextField(blank=True, verbose_name="Face URL")
    added_at = models.TextField(blank=True, verbose_name="Added At")

    def __str__(self):
        return f"{self.full_name} ({self.branch.university_name})"

# ===============================================================================================
# 5. STAFF & LOGS
# ===============================================================================================

class AdminStaffMember(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uid = models.CharField(max_length=255,unique=False, verbose_name="UID") 
    full_name = models.CharField(max_length=255, verbose_name="Full Name")
    name = models.CharField(max_length=255, verbose_name="First Name")
    surname = models.CharField(max_length=255, verbose_name="Surname")
    gender = models.CharField(max_length=50, choices=GENDER_CHOICES, blank=True, null=True)
    email = models.EmailField(verbose_name="Email")
    personal_email = models.EmailField(blank=True, verbose_name="Personal Email")
    role = models.CharField(max_length=255, verbose_name="Role")
    portfolio = models.CharField(max_length=255, blank=True, verbose_name="Portfolio")
    province = models.CharField(max_length=255, blank=True, verbose_name="Province")
    face_url = models.TextField(blank=True, verbose_name="Face URL")
    is_active = models.BooleanField(default=True, verbose_name="Is Active")
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return f"{self.full_name} ({self.role})"

class AuditLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    action = models.CharField(max_length=255, verbose_name="Action")
    details = models.TextField(verbose_name="Details") 
    actor_name = models.CharField(max_length=255, verbose_name="Actor Name")
    actor_role = models.CharField(max_length=255, verbose_name="Actor Role")
    actor_face_url = models.TextField(blank=True, verbose_name="Actor Face URL")
    uid = models.CharField(max_length=255, verbose_name="User UID")
    university_name = models.CharField(max_length=255, blank=True, verbose_name="University Name")
    university_logo = models.TextField(blank=True, verbose_name="University Logo")
    branch_email = models.EmailField(blank=True, verbose_name="Branch Email")
    target_member_name = models.CharField(max_length=255, blank=True, verbose_name="Target Member Name")
    target_member_role = models.CharField(max_length=255, blank=True, verbose_name="Target Member Role")
    student_name = models.CharField(max_length=255, blank=True, default="N/A", verbose_name="Student Name")
    timestamp = models.TextField(verbose_name="Timestamp")
    device_time = models.CharField(max_length=255, blank=True, verbose_name="Device Time")

    def __str__(self):
        return f"{self.action} - {self.actor_name}"
    
class UsersHelp(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    description =models.TextField(max_length =255,verbose_name="Description")
    status=models.BooleanField(default=False)
    subject = models.TextField(max_length=255,blank=True)
    user_email = models.EmailField(max_length=255,blank=True)
    time_stamp = models.DateTimeField(max_length=255,default=timezone.now,auto_created=True)
    user_id = models.TextField(max_length=255,verbose_name="User ID")
    
    def __str__(self):
        return f"Ticket {self.user_email}"

class AttendanceLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    community_name = models.CharField(max_length=255, db_index=True)
    member_uid = models.CharField(max_length=255, db_index=True)
    is_visitor = models.BooleanField(default=False)
    date = models.DateField(default=timezone.now, db_index=True)
    is_present = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta: 
        unique_together = ('member_uid', 'date')

    def __str__(self):
        return f"{self.community_name} - {self.member_uid} - {self.date}: {self.is_present}"
    
class ContributionHistory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    overseer_uid = models.CharField(max_length=255)
    user_uid = models.CharField(max_length=255) 
    name = models.CharField(max_length=255)
    surname = models.CharField(max_length=255)
    district_elder = models.CharField(max_length=255)
    community = models.CharField(max_length=255)
    month = models.IntegerField()
    year = models.IntegerField()
    week1 = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    week2 = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    week3 = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    week4 = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    archived_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.month}/{self.year}"

class MonthlyReport(models.Model):
    id = models.CharField(primary_key=True, max_length=255) 
    community_name = models.CharField(max_length=255)
    year = models.IntegerField()
    month = models.IntegerField()
    month_end = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    others = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    rent = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    wine = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    power = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    sundries = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    council = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    equipment = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    date_week1 = models.CharField(max_length=255, blank=True, null=True)
    date_week2 = models.CharField(max_length=255, blank=True, null=True)
    date_week3 = models.CharField(max_length=255, blank=True, null=True)
    date_week4 = models.CharField(max_length=255, blank=True, null=True)
    date_month_end = models.CharField(max_length=255, blank=True, null=True)
    date_others = models.CharField(max_length=255, blank=True, null=True)
    date_rent = models.CharField(max_length=255, blank=True, null=True)
    date_wine = models.CharField(max_length=255, blank=True, null=True)
    date_power = models.CharField(max_length=255, blank=True, null=True)
    date_sundries = models.CharField(max_length=255, blank=True, null=True)
    date_council = models.CharField(max_length=255, blank=True, null=True)
    date_equipment = models.CharField(max_length=255, blank=True, null=True)
    archived_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.id
    
class IssueReport(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255, verbose_name="Title")
    description = models.TextField(verbose_name="Description")
    reported_by = models.CharField(max_length=255, verbose_name="Reported By")
    reported_at = models.DateTimeField(auto_now_add=True, verbose_name="Reported At")
    is_resolved = models.BooleanField(default=False, verbose_name="Is Resolved")
    resolved_at = models.DateTimeField(blank=True, null=True, verbose_name="Resolved At")

    def __str__(self):
        return self.title
    
class EventDiary(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255, verbose_name="Event Title")
    day = models.CharField(max_length=255, verbose_name="Day (e.g., 18 or 11 - 12)")
    month = models.CharField(max_length=255, blank=True, verbose_name="Month (e.g., Apr)")
    year = models.IntegerField(verbose_name="Year")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['year', 'month', 'day']

    def __str__(self):
        return f"{self.title} ({self.day} {self.month} {self.year})"

class EventContribution(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event = models.ForeignKey(EventDiary, related_name='contributions', on_delete=models.CASCADE)
    overseer = models.ForeignKey(Overseer, related_name='event_contributions', on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Amount Contributed")
    has_contributed = models.BooleanField(default=False)
    remarks = models.TextField(blank=True, null=True)
    contribution_date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.overseer.overseer_initials_surname} -> {self.event.title}"
 
class ApostolicGreeting(models.Model):
    id = models.CharField(primary_key=True, max_length=255, verbose_name="Greeting ID (Year)")
    year = models.CharField(max_length=255, verbose_name="Year")
    apostle = models.CharField(max_length=255, verbose_name="Apostle Name")
    role = models.CharField(max_length=255, verbose_name="Role")
    image_url = models.TextField(default='assets/profile_placeholder.png', verbose_name="Image URL")
    content_json = models.JSONField(default=dict, verbose_name="Translations (JSON)")
    
    # Engagement Metrics
    likes = models.PositiveIntegerField(default=0)
    views = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-year']

    def __str__(self):
        return f"{self.apostle} - {self.year}"
