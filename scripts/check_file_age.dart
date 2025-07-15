#!/usr/bin/env dart

import 'dart:io';

/// Utility script to check if a file is older than a specified number of hours
/// Returns exit code 0 if file needs updating (doesn't exist or is too old)
/// Returns exit code 1 if file is fresh enough
/// 
/// Usage: dart scripts/check_file_age.dart <file_path> [hours]

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart scripts/check_file_age.dart <file_path> [hours]');
    print('Default: 24 hours if not specified');
    exit(2);
  }

  final filePath = args[0];
  final hours = args.length > 1 ? int.tryParse(args[1]) ?? 24 : 24;
  
  final file = File(filePath);
  
  // If file doesn't exist, it needs updating
  if (!await file.exists()) {
    if (args.contains('--verbose')) {
      print('File does not exist: $filePath');
    }
    exit(0); // Needs update
  }
  
  // Check file age
  final fileStat = await file.stat();
  final fileAge = DateTime.now().difference(fileStat.modified);
  final maxAge = Duration(hours: hours);
  
  if (args.contains('--verbose')) {
    print('File: $filePath');
    print('Last modified: ${fileStat.modified}');
    print('Age: ${fileAge.inHours} hours ${fileAge.inMinutes % 60} minutes');
    print('Max allowed age: ${maxAge.inHours} hours');
  }
  
  if (fileAge > maxAge) {
    if (args.contains('--verbose')) {
      print('File is older than $hours hours - needs update');
    }
    exit(0); // Needs update
  } else {
    if (args.contains('--verbose')) {
      print('File is fresh (less than $hours hours old)');
    }
    exit(1); // Fresh enough
  }
}