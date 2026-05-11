import * as admin from 'firebase-admin';

// ─── Domain roles ─────────────────────────────────────────────────────────────
export type UserRole =
  | 'student'
  | 'parent'
  | 'tutor'
  | 'academic_staff'
  | 'super_admin';

// ─── User profile (mirrors /users/{uid} Firestore doc) ────────────────────────
export interface UserProfile {
  uid:                  string;
  email:                string;
  role:                 UserRole;
  displayName:          string;
  phoneNumber?:         string;
  country?:             string;
  // Student-only: parent UIDs that have linked this account
  parentIds?:           string[];
  // Parent-only: student UIDs this parent has linked
  linkedStudentIds?:    string[];
  // Flag: can this account review flagged content? Set by super_admin only.
  isContentModerator?:  boolean;
  isActive:             boolean;
  createdAt:            admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt:            admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// ─── Booking ──────────────────────────────────────────────────────────────────
export type BookingStatus = 'pending' | 'confirmed' | 'cancelled' | 'completed';
export type SessionType   = 'one_on_one' | 'group';
export type Currency      = 'XOF' | 'GNF' | 'XAF' | 'CFA';

export interface CreateBookingRequest {
  tutorId:         string;
  subjectId:       string;
  scheduledAt:     admin.firestore.Timestamp;
  durationMinutes: 30 | 60 | 90;
  sessionType:     SessionType;
  // Provided when a parent books on behalf of a student
  studentId?:      string;
}

export interface BookingDocument {
  id:              string;
  studentId:       string;
  tutorId:         string;
  subjectId:       string;
  scheduledAt:     admin.firestore.Timestamp | admin.firestore.FieldValue;
  durationMinutes: number;
  sessionType:     SessionType;
  parentId?:       string;
  status:          BookingStatus;
  sessionId?:      string;
  reminderSent?:   boolean;
  totalAmount:     number;
  currency:        Currency;
  createdAt:       admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt:       admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// ─── Tutor application ────────────────────────────────────────────────────────
export type TutorApplicationStatus =
  | 'pending_document_review'
  | 'background_check_pending'
  | 'approved'
  | 'rejected';

export interface TutorApplicationDocument {
  type:        'cv' | 'national_id' | 'diploma' | 'other';
  storagePath: string; // gs://bucket/path
  uploadedAt:  admin.firestore.Timestamp | admin.firestore.FieldValue;
}

export interface TutorApplication {
  id:                    string;
  userId:                string;
  fullName:              string;
  phoneNumber:           string;
  subjects:              string[];
  gradeLevels:           string[];
  bio:                   string;
  country:               string;
  diplomas:              string[];
  yearsExperience:       number;
  status:                TutorApplicationStatus;
  backgroundCheckStatus: 'pending' | 'clear' | 'flagged';
  documents:             TutorApplicationDocument[];
  reviewedBy?:           string;
  reviewedAt?:           admin.firestore.Timestamp | admin.firestore.FieldValue;
  rejectionReason?:      string;
  createdAt:             admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt:             admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// ─── Parent–child link request ────────────────────────────────────────────────
export type LinkRequestStatus =
  | 'pending_admin_verification'
  | 'approved'
  | 'rejected';

export interface ParentLinkRequest {
  id:               string;
  parentId:         string;
  studentId:        string;
  studentEmail:     string;
  relationship:     'parent' | 'guardian' | 'grandparent' | 'other';
  status:           LinkRequestStatus;
  reviewedBy?:      string;
  reviewedAt?:      admin.firestore.Timestamp | admin.firestore.FieldValue;
  rejectionReason?: string;
  createdAt:        admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt:        admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// ─── Flagged content (content moderation) ────────────────────────────────────
export interface FlaggedContent {
  id:              string;
  userId:          string;
  endpoint:        string;
  contentSnippet:  string; // first 300 chars of flagged text
  matchedPattern:  string;
  status:          'pending_review' | 'reviewed_safe' | 'reviewed_harmful';
  reviewedBy?:     string;
  reviewedAt?:     admin.firestore.Timestamp | admin.firestore.FieldValue;
  createdAt:       admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// ─── Payment ──────────────────────────────────────────────────────────────────
export type PaymentStatus   = 'pending' | 'success' | 'failed' | 'refunded';
export type PaymentProvider = 'flutterwave' | 'orange_money' | 'wave';

export interface PaymentDocument {
  id:                    string;
  bookingId:             string;
  userId:                string;
  amount:                number;
  currency:              string;
  provider:              PaymentProvider;
  providerTransactionId: string;
  status:                PaymentStatus;
  processedAt?:          admin.firestore.Timestamp | admin.firestore.FieldValue;
  createdAt:             admin.firestore.Timestamp | admin.firestore.FieldValue;
  // Raw webhook payload stored for audit trail — never used in business logic
  webhookPayload:        Record<string, unknown>;
}
