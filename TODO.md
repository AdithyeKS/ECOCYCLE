# TODO: Fix decideOnApplication Error

## Completed Tasks

- [x] Identified the root cause: updateProfile() method using upsert without setting user_role, causing constraint violation when inserting new profiles
- [x] Fixed updateProfile() to include 'user_role': 'user' in the upsert operation

## Next Steps

- [ ] Test the fix by running the application and attempting to approve/reject a volunteer application
- [ ] Verify that the constraint violation no longer occurs
- [ ] If issues persist, check if the database schema needs to be updated to include 'volunteer' in the check constraint
