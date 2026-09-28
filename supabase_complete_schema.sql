-- =====================================================================
-- ISKOOL ERP COMPLETE SUPABASE DATABASE SCHEMA INITIALIZATION
-- Run this in your Supabase Dashboard -> SQL Editor (New Query -> Run)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. SCHOOLS TABLE (Multi-Tenant Core)
CREATE TABLE IF NOT EXISTS public.schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  logo_url TEXT,
  address TEXT,
  phone VARCHAR(50),
  email VARCHAR(100),
  max_students INT DEFAULT 250,
  is_active BOOLEAN DEFAULT true,
  currency_symbol VARCHAR(10) DEFAULT '$',
  admission_prefix VARCHAR(20) DEFAULT 'SCH-2026-',
  receipt_prefix VARCHAR(20) DEFAULT 'REC-2026-',
  academic_year VARCHAR(20) DEFAULT '2026-2027',
  tagline VARCHAR(255) DEFAULT 'Excellence in Academic Mastery',
  fee_due_day INT DEFAULT 10,
  valid_until TIMESTAMPTZ DEFAULT (now() + interval '1 year'),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. CLASSES TABLE
CREATE TABLE IF NOT EXISTS public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  section VARCHAR(20) DEFAULT 'A',
  room_number VARCHAR(50),
  tuition_fee NUMERIC(10,2) DEFAULT 1200.00,
  admission_fee NUMERIC(10,2) DEFAULT 2500.00,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. SECTIONS TABLE
CREATE TABLE IF NOT EXISTS public.sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  name VARCHAR(20) NOT NULL,
  room_number VARCHAR(50),
  capacity INT DEFAULT 40,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. PARENTS TABLE
CREATE TABLE IF NOT EXISTS public.parents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  father_name VARCHAR(100),
  mother_name VARCHAR(100),
  primary_phone VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. STUDENTS TABLE (SIS with eSkooly demographics)
CREATE TABLE IF NOT EXISTS public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  admission_no VARCHAR(50) NOT NULL,
  roll_no VARCHAR(50),
  full_name VARCHAR(200) NOT NULL,
  class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  section VARCHAR(20),
  parent_name VARCHAR(200),
  parent_phone VARCHAR(50),
  gender VARCHAR(20) DEFAULT 'Male',
  blood_group VARCHAR(10) DEFAULT 'O+',
  status VARCHAR(20) DEFAULT 'active',
  dob DATE,
  religion VARCHAR(50),
  category VARCHAR(50) DEFAULT 'General',
  address TEXT,
  emergency_phone VARCHAR(50),
  father_name VARCHAR(100),
  father_phone VARCHAR(50),
  mother_name VARCHAR(100),
  mother_phone VARCHAR(50),
  fee_discount_percent NUMERIC(5,2) DEFAULT 0.00,
  admission_date DATE DEFAULT CURRENT_DATE,
  previous_school VARCHAR(200),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. TEACHERS / STAFF TABLE (eSkooly HR)
CREATE TABLE IF NOT EXISTS public.teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  employee_code VARCHAR(50) NOT NULL,
  full_name VARCHAR(200) NOT NULL,
  phone VARCHAR(50),
  email VARCHAR(100),
  role VARCHAR(50) DEFAULT 'Teacher',
  designation VARCHAR(100) DEFAULT 'Faculty',
  department VARCHAR(100) DEFAULT 'Academics',
  salary NUMERIC(10,2) DEFAULT 35000.00,
  qualification VARCHAR(200),
  specialization VARCHAR(200),
  joining_date DATE DEFAULT CURRENT_DATE,
  is_active BOOLEAN DEFAULT true,
  father_or_husband_name VARCHAR(100),
  gender VARCHAR(20) DEFAULT 'Male',
  experience VARCHAR(100),
  national_id VARCHAR(100),
  religion VARCHAR(50) DEFAULT 'Islam',
  blood_group VARCHAR(10) DEFAULT 'O+',
  dob DATE,
  home_address TEXT,
  picture_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. FEE COLLECTIONS TABLE (Cash counter payments)
CREATE TABLE IF NOT EXISTS public.fee_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  receipt_no VARCHAR(50) NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL,
  payment_date TIMESTAMPTZ DEFAULT now(),
  payment_mode VARCHAR(50) DEFAULT 'Cash',
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. FEE INVOICES TABLE
CREATE TABLE IF NOT EXISTS public.fee_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  invoice_no VARCHAR(50) NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  month VARCHAR(50) NOT NULL,
  due_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'Pending',
  paid_amount NUMERIC(10,2) DEFAULT 0.00,
  paid_date DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. EXPENSES TABLE (Accounts ledger)
CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  category VARCHAR(100) NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  payment_date DATE DEFAULT CURRENT_DATE,
  payment_method VARCHAR(50) DEFAULT 'Cash',
  receipt_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'Present',
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(school_id, student_id, date)
);

-- 11. GRADING SCALES TABLE
CREATE TABLE IF NOT EXISTS public.grading_scales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  grade VARCHAR(10) NOT NULL,
  min_percentage NUMERIC(5,2) NOT NULL,
  max_percentage NUMERIC(5,2) NOT NULL,
  grade_point NUMERIC(4,2) DEFAULT 0.0,
  description VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. EXAM MARKS TABLE
CREATE TABLE IF NOT EXISTS public.exam_marks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  exam_name VARCHAR(100) NOT NULL,
  subject_name VARCHAR(100) NOT NULL,
  marks_obtained NUMERIC(5,2) NOT NULL,
  max_marks NUMERIC(5,2) NOT NULL DEFAULT 100.00,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 13. TIMETABLE SLOTS TABLE (Interactive Timetable Management)
CREATE TABLE IF NOT EXISTS public.timetable_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  section VARCHAR(20) DEFAULT 'A',
  day_of_week VARCHAR(20) NOT NULL, -- Monday, Tuesday, etc.
  period_number INT NOT NULL,
  start_time VARCHAR(10) NOT NULL,
  end_time VARCHAR(10) NOT NULL,
  subject_name VARCHAR(100) NOT NULL,
  teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  room_number VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 14. LESSON PLANS TABLE (Academic Curriculum Tracking)
CREATE TABLE IF NOT EXISTS public.lesson_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  subject_name VARCHAR(100) NOT NULL,
  teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  topic_title VARCHAR(255) NOT NULL,
  objectives TEXT,
  planned_date DATE DEFAULT CURRENT_DATE,
  status VARCHAR(20) DEFAULT 'Planned', -- Planned, In Progress, Completed
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 15. TEACHING LOGBOOKS TABLE (Daily Teacher Syllabus Entries)
CREATE TABLE IF NOT EXISTS public.teaching_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  subject_name VARCHAR(100) NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  period_number INT DEFAULT 1,
  activity_summary TEXT NOT NULL,
  homework_assigned TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 16. PTM (PARENT-TEACHER MEETING) SLOTS TABLE
CREATE TABLE IF NOT EXISTS public.ptm_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
  slot_date DATE NOT NULL,
  slot_time VARCHAR(20) NOT NULL,
  status VARCHAR(20) DEFAULT 'Available', -- Available, Booked, Completed
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 17. STUDENT CONDUCT & DISCIPLINE TABLE
CREATE TABLE IF NOT EXISTS public.student_discipline (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  incident_date DATE NOT NULL DEFAULT CURRENT_DATE,
  category VARCHAR(50) DEFAULT 'Behavioral', -- Behavioral, Academic, Merit/Award, Attendance
  severity VARCHAR(20) DEFAULT 'Minor', -- Minor, Moderate, Major, Commendation
  description TEXT NOT NULL,
  action_taken TEXT,
  reported_by VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 18. SUBSTITUTE TEACHER ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.substitute_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  original_teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  substitute_teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  period_number INT NOT NULL,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  reason TEXT,
  status VARCHAR(20) DEFAULT 'Assigned',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 19. SCHOOL NOTICES & CIRCULARS TABLE
CREATE TABLE IF NOT EXISTS public.school_notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  target_audience VARCHAR(50) DEFAULT 'All', -- All, Teachers, Parents, Students
  publish_date DATE DEFAULT CURRENT_DATE,
  is_urgent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 20. INVENTORY / ASSET REGISTER TABLE
CREATE TABLE IF NOT EXISTS public.inventory_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  item_name VARCHAR(200) NOT NULL,
  category VARCHAR(100) NOT NULL, -- IT Hardware, Lab Equipment, Furniture, Sports, Library
  quantity INT NOT NULL DEFAULT 1,
  condition VARCHAR(50) DEFAULT 'Good', -- New, Good, Needs Repair, Discarded
  location VARCHAR(100),
  purchase_date DATE,
  cost NUMERIC(10,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================================
-- PERMISSIONS & ROW-LEVEL SECURITY (RLS) POLICIES
-- Enables Full Browser Anon/Public CRUD Operations (No 42501 Errors)
-- =====================================================================

DO $$
DECLARE
  tbl text;
  tables text[] := ARRAY[
    'schools', 'classes', 'sections', 'parents', 'students',
    'teachers', 'fee_collections', 'fee_invoices', 'expenses',
    'attendance', 'grading_scales', 'exam_marks',
    'timetable_slots', 'lesson_plans', 'teaching_logs',
    'ptm_slots', 'student_discipline', 'substitute_assignments',
    'school_notices', 'inventory_assets'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow all access" ON public.%I;', tbl);
    EXECUTE format('CREATE POLICY "Allow all access" ON public.%I FOR ALL TO public USING (true) WITH CHECK (true);', tbl);
  END LOOP;
END $$;

-- =====================================================================
-- SEED DEFAULT DEMO DATA
-- =====================================================================

INSERT INTO public.schools (
  id, name, code, address, phone, email, max_students, is_active,
  currency_symbol, admission_prefix, receipt_prefix, academic_year, tagline, fee_due_day
) VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'Greenwood International Academy',
  'GIA-2026',
  'Plot 42, Knowledge Park III, Silicon Valley',
  '+91 98765 43210',
  'office@greenwood.edu',
  250,
  true,
  '$',
  'SCH-2026-',
  'REC-2026-',
  '2026-2027',
  'Excellence in Academic Mastery',
  10
) ON CONFLICT (code) DO NOTHING;

-- Seed Sample Classes
INSERT INTO public.classes (id, school_id, name, section, room_number, tuition_fee, admission_fee)
VALUES 
  ('c1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Grade 10', 'A', 'Room 101', 1500.00, 3000.00),
  ('c2222222-2222-2222-2222-222222222222', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Grade 9', 'A', 'Room 201', 1400.00, 2800.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Sample Sections
INSERT INTO public.sections (id, school_id, class_id, name, room_number, capacity)
VALUES 
  ('s1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c1111111-1111-1111-1111-111111111111', 'A', 'Room 101', 40),
  ('s2222222-2222-2222-2222-222222222222', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c2222222-2222-2222-2222-222222222222', 'A', 'Room 201', 40)
ON CONFLICT (id) DO NOTHING;

-- Seed Sample Teacher
INSERT INTO public.teachers (
  id, school_id, employee_code, full_name, role, designation, department,
  salary, qualification, phone, email, father_or_husband_name, gender,
  experience, national_id, religion, blood_group
) VALUES (
  't1111111-1111-1111-1111-111111111111',
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'EMP-2026-001',
  'Dr. Sarah Jenkins',
  'Principal',
  'Head of Institution',
  'Administration',
  65000.00,
  'Ph.D Educational Leadership, M.Sc',
  '+1 555-0199',
  'sarah.jenkins@greenwood.edu',
  'David Jenkins',
  'Female',
  '12 Years',
  'NAT-998877',
  'Christianity',
  'O+'
) ON CONFLICT (id) DO NOTHING;
