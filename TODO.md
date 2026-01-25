# TODO: Add YouTube Icon for Demonstration Video

## Completed Tasks

- [x] Add url_launcher import to home_screen.dart
- [x] Add YouTube icon button as leading icon in app bar on home screen
- [x] Implement onPressed to launch YouTube link using placeholder URL
- [x] Add error handling for link launch failure
- [x] Replace YouTube demo icon with menu containing YouTube demo and profile options

## Pending Tasks

- [ ] Update placeholder YouTube link with actual demonstration video URL (to be provided by user)
- [ ] Test the menu functionality on device/emulator

## Notes

- Placeholder URL: https://www.youtube.com/watch?v=dQw4w9WgXcQ
- Menu uses PopupMenuButton with Icons.menu
- Menu items: YouTube demo (play icon) and Profile (person icon)
- Profile icon removed from actions and moved to menu
- Uses url_launcher package for opening external links
