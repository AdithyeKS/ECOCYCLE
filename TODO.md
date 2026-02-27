# TODO: Enhance Plastic Waste Image Validation

## Tasks

- [x] Modify \_detectPlastic method to show AlertDialog for rejection cases instead of snackbar
- [x] For NON_PLASTIC: Show dialog "Invalid Item Type" with message "This is not a plastic waste item. Please add only plastic waste items here."
- [x] For poor_quality: Show dialog "Image Quality Issue" with message about clarity
- [x] For human_detected: Show dialog "Invalid Image" with message
- [x] In all rejection cases, clear image, picked file, and reset fields
- [x] Ensure submit button is disabled without valid image
- [x] Test the changes
