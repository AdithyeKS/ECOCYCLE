# TODO: Fix Admin Login Issue

## Problem

When logging in with "admin" as email and password, the user is redirected to the regular user home page instead of the admin dashboard.

## Root Cause

- The `profiles` table was missing the `user_role` column.
- Inconsistent column naming: some code used 'role', others 'user_role'.
- Admin user likely doesn't have `user_role` set to 'admin' in the database.

## Plan

- [x] Update `supabase_schema.sql` to add `user_role` and `volunteer_requested_at` columns to profiles table.
- [x] Update `login_screen.dart` to use 'user_role' instead of 'role'.
- [x] Update `home_shell.dart` to use 'user_role' instead of 'role'.
- [ ] Apply the schema changes to Supabase database.
- [ ] Set the admin user's role to 'admin' in the database.
- [ ] Test the login with admin credentials.

## Followup Steps

Run these SQL commands in your Supabase SQL editor (in order):

1. **Create the pickup_requests table (renamed from pickup_agents):**

   ```sql
   CREATE TABLE IF NOT EXISTS pickup_requests (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     name TEXT NOT NULL,
     phone TEXT NOT NULL,
     email TEXT,
     vehicle_number TEXT,
     is_active BOOLEAN DEFAULT TRUE,
     current_latitude DOUBLE PRECISION,
     current_longitude DOUBLE PRECISION,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

2. **Update foreign key reference in ewaste_items:**

   ```sql
   ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES pickup_requests(id);
   ```

3. **Add the user_role column:**

   ```sql
   ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_role TEXT DEFAULT 'user';
   ```

4. **Add the volunteer_requested_at column:**

   ```sql
   ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS volunteer_requested_at TIMESTAMP WITH TIME ZONE;
   ```

5. **Temporarily disable RLS to fix recursion issue:**

   ```sql
   ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
   ```

6. **Create/ensure the admin user's profile exists and set role:**

   ```sql
   INSERT INTO public.profiles (id, user_role, full_name, total_points, created_at)
   VALUES ('cbc9b962-26de-48ec-bf7d-f0502bb3e758', 'admin', 'Admin User', 0, NOW())
   ON CONFLICT (id) DO UPDATE SET user_role = 'admin';
   ```

7. **Test login functionality** with "admin" as email and password - it should now redirect to the admin dashboard.

8. **After testing, re-enable RLS with proper policies:**
   ```sql
   ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid()::text = id::text);
   CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid()::text = id::text);
   CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid()::text = id::text);
   ```
