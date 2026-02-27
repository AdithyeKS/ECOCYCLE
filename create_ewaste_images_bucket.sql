-- Create the 'ewaste_images' storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ewaste_images',
  'ewaste_images',
  true,  -- Make it public
  5242880,  -- 5MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']  -- Allowed image types
)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies for the bucket
-- Allow authenticated users to upload images
CREATE POLICY "Users can upload images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'ewaste_images'
  AND auth.role() = 'authenticated'
);

-- Allow public access to view images
CREATE POLICY "Public can view images" ON storage.objects
FOR SELECT USING (bucket_id = 'ewaste_images');

-- Allow users to update their own images
CREATE POLICY "Users can update own images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'ewaste_images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own images
CREATE POLICY "Users can delete own images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'ewaste_images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
