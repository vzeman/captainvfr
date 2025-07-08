# Dialog Theming Guide

This guide explains how to use the new themed dialog system that matches the flight data panel style.

## Style Overview

The themed dialogs use:
- Dark background with 90% opacity (`Color(0xE6000000)`)
- Blue accent border (`Color(0x7F448AFF)`)
- Rounded corners (12px radius)
- White text on dark background
- Blue accent for interactive elements

## Basic Usage

### 1. Using ThemedDialog directly

```dart
import '../widgets/themed_dialog.dart';

// Simple dialog
ThemedDialog.show(
  context: context,
  title: 'Dialog Title',
  content: Text('Dialog content', style: TextStyle(color: Colors.white70)),
  actions: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.of(context).pop(true),
      child: Text('OK'),
    ),
  ],
);
```

### 2. Using convenience methods

```dart
// Confirmation dialog
final confirmed = await ThemedDialog.showConfirmation(
  context: context,
  title: 'Delete Item',
  message: 'Are you sure you want to delete this item?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  destructive: true, // Makes confirm button red
);

if (confirmed == true) {
  // Perform delete action
}
```

### 3. Using DialogHelper for common patterns

```dart
import '../utils/dialog_helper.dart';

// Input dialog
final name = await DialogHelper.showInputDialog(
  context: context,
  title: 'Enter Name',
  labelText: 'Name',
  hintText: 'Enter your name',
  validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
);

// Selection dialog
final selected = await DialogHelper.showSelectionDialog<String>(
  context: context,
  title: 'Select Option',
  items: ['Option 1', 'Option 2', 'Option 3'],
  itemBuilder: (item) => item,
  selectedItem: currentSelection,
);

// Loading dialog
DialogHelper.showLoadingDialog(
  context: context,
  message: 'Processing...',
);
// Close it later with Navigator.of(context).pop();
```

## Migration Guide

### Converting AlertDialog to ThemedDialog

Before:
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Title'),
    content: Text('Content'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel'),
      ),
    ],
  ),
);
```

After:
```dart
ThemedDialog.show(
  context: context,
  title: 'Title',
  content: Text('Content', style: TextStyle(color: Colors.white70)),
  actions: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel'),
    ),
  ],
);
```

### Form Fields in Dialogs

When using form fields in themed dialogs, make sure to style them appropriately:

```dart
TextFormField(
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    labelText: 'Label',
    filled: true,
    fillColor: const Color(0x1A448AFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0x7F448AFF)),
    ),
    // ... other decoration properties
  ),
)
```

## Color Reference

- Background: `Color(0xE6000000)` - Black with 90% opacity
- Border: `Color(0x7F448AFF)` - Blue accent with 50% opacity  
- Selected/Active: `Color(0xFF448AFF)` - Full blue accent
- Text Primary: `Colors.white`
- Text Secondary: `Colors.white70`
- Text Hint: `Colors.white30`
- Input Background: `Color(0x1A448AFF)` - Blue accent with 10% opacity

## Examples in the Codebase

- Flight log delete confirmation: `lib/screens/flight_log_screen.dart`
- Aircraft selection dialog: `lib/widgets/flight_dashboard.dart`

## Best Practices

1. Always use `Colors.white70` for body text and `Colors.white` for titles
2. Use the blue accent color (`Color(0xFF448AFF)`) for selected items and primary actions
3. Keep dialog content concise and readable
4. Use proper spacing and padding for better readability
5. For destructive actions, use the `destructive: true` flag in confirmation dialogs