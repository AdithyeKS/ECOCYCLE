-- ============================================================================
-- TEST DATA INSERTION FOR ADMIN DASHBOARD TESTING
-- ============================================================================

-- Insert test NGOs
INSERT INTO ngos (name, description, address, phone, email, is_government_approved, latitude, longitude) VALUES
  ('Green Recycling Center', 'Main e-waste recycling facility', '123 Green Street, Eco City', '+1-555-0123', 'contact@greenrecycling.com', true, 40.7128, -74.0060),
  ('Tech Waste Solutions', 'Specialized electronics recycling', '456 Tech Avenue, Innovation District', '+1-555-0456', 'info@techwaste.com', true, 40.7589, -73.9851),
  ('Eco Partners NGO', 'Community recycling initiative', '789 Eco Boulevard, Green Valley', '+1-555-0789', 'partners@ecopartners.org', false, 40.7505, -73.9934)
ON CONFLICT DO NOTHING;

-- Insert test profiles (replace with actual auth user IDs)
-- NOTE: Replace the UUIDs below with actual user IDs from your auth.users table
INSERT INTO profiles (id, full_name, email, phone_number, address, user_role, total_points) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'John Admin', 'admin@ecocycle.com', '+1-555-0001', '123 Admin Street', 'admin', 500),
  ('550e8400-e29b-41d4-a716-446655440001', 'Sarah Agent', 'agent@ecocycle.com', '+1-555-0002', '456 Agent Avenue', 'agent', 300),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike User', 'user@ecocycle.com', '+1-555-0003', '789 User Boulevard', 'user', 150),
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', 'volunteer@ecocycle.com', '+1-555-0004', '321 Volunteer Lane', 'volunteer', 200)
ON CONFLICT (id) DO NOTHING;

-- Insert test e-waste items
INSERT INTO ewaste_items (user_id, item_name, description, location, category_id, status, reward_points, assigned_agent_id, assigned_ngo_id, delivery_status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Old Laptop', 'Dell Latitude E5450, 8GB RAM, 256GB SSD', 'Downtown Office', 'Computers', 'pending', 80, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Smartphone', 'iPhone 12 Pro, 256GB, good condition', 'Residential Area', 'Phones', 'assigned', 50, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1), 'assigned'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Monitor', '27-inch 4K Dell Monitor', 'Business District', 'Monitors', 'collected', 40, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1 OFFSET 1), 'collected'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Wireless Headphones', 'Sony WH-1000XM4, excellent condition', 'Shopping Mall', 'Headphones', 'pending', 25, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Tablet', 'iPad Air 4th Gen, 64GB', 'Residential Complex', 'Tablets', 'delivered', 35, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1 OFFSET 2), 'delivered')
ON CONFLICT DO NOTHING;

-- Insert test pickup agents
INSERT INTO pickup_requests (agent_id, name, phone, email, vehicle_number, is_active, current_latitude, current_longitude) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Sarah Agent', '+1-555-0002', 'agent@ecocycle.com', 'ECO-001', true, 40.7128, -74.0060),
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', '+1-555-0004', 'volunteer@ecocycle.com', 'VOL-001', true, 40.7589, -73.9851)
ON CONFLICT DO NOTHING;

-- Insert test volunteer applications
INSERT INTO volunteer_applications (user_id, full_name, email, phone, address, available_date, motivation, agreed_to_policy, status) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', 'volunteer@ecocycle.com', '+1-555-0004', '321 Volunteer Lane', '2024-02-15', 'I want to contribute to environmental sustainability by helping with e-waste collection and recycling efforts.', true, 'approved'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike User', 'user@ecocycle.com', '+1-555-0003', '789 User Boulevard', '2024-02-20', 'Passionate about reducing electronic waste and making a positive impact on the community.', true, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440000', 'John Admin', 'admin@ecocycle.com', '+1-555-0001', '123 Admin Street', '2024-02-10', 'As an admin, I want to help coordinate volunteer efforts.', true, 'approved')
ON CONFLICT DO NOTHING;

-- Insert test volunteer schedules
INSERT INTO volunteer_schedules (volunteer_id, date, is_available) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE, true),
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE + INTERVAL '1 day', true),
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE + INTERVAL '2 days', false),
  ('550e8400-e29b-41d4-a716-446655440001', CURRENT_DATE, true),
  ('550e8400-e29b-41d4-a716-446655440001', CURRENT_DATE + INTERVAL '1 day', true)
ON CONFLICT DO NOTHING;

-- Insert test volunteer assignments
INSERT INTO volunteer_assignments (volunteer_id, ewaste_item_id, task_type, scheduled_date, status, notes) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', (SELECT id FROM ewaste_items LIMIT 1), 'pickup_delivery', CURRENT_DATE, 'assigned', 'Pickup scheduled for morning'),
  ('550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ewaste_items LIMIT 1 OFFSET 1), 'pickup_delivery', CURRENT_DATE, 'completed', 'Successfully delivered to recycling center')
ON CONFLICT DO NOTHING;

-- Insert test user rewards
INSERT INTO user_rewards (user_id, points, total_waste_kg, total_pickups, level) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 500, 25.5, 15, 'expert'),
  ('550e8400-e29b-41d4-a716-446655440001', 300, 15.2, 8, 'advanced'),
  ('550e8400-e29b-41d4-a716-446655440002', 150, 8.7, 4, 'intermediate'),
  ('550e8400-e29b-41d4-a716-446655440003', 200, 12.3, 6, 'advanced')
ON CONFLICT (user_id) DO NOTHING;

-- Insert test cloth items
INSERT INTO cloth_items (user_id, item_name, description, location, category, status, reward_points, assigned_agent_id, assigned_ngo_id, delivery_status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Winter Coat', 'Wool coat, size M, good condition', 'Community Center', 'Clothing', 'pending', 15, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Jeans Collection', '5 pairs of jeans, various sizes', 'Residential Area', 'Clothing', 'assigned', 25, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1), 'collected')
ON CONFLICT DO NOTHING;

-- Insert test notifications
INSERT INTO notifications (user_id, title, message, type, is_read) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Item Submitted', 'Your laptop has been successfully submitted for recycling. You earned 80 EcoPoints!', 'success', false),
  ('550e8400-e29b-41d4-a716-446655440001', 'New Assignment', 'You have been assigned to pick up a smartphone in the residential area.', 'info', false),
  ('550e8400-e29b-41d4-a716-446655440003', 'Volunteer Application Approved', 'Congratulations! Your volunteer application has been approved.', 'success', true)
ON CONFLICT DO NOTHING;
