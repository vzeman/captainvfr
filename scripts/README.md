# Aviation Data Download Scripts

These scripts download aviation data from OpenAIP (airports, airspaces, reporting points) and OurAirports (frequencies, navaids) to bundle with the app for offline use.

## Prerequisites

1. Dart SDK installed
2. Good internet connection (downloads ~80 tiles each for airspaces and reporting points)
3. Optional: Your own OpenAIP API key (get one from https://www.openaip.net/)
   - If not provided, the scripts use the default API key from the app

## Usage

### Download All Data

The easiest way is to use the convenience script:

```bash
# Download only if data is older than 24 hours (default)
./scripts/download_all_data.sh

# Force download all data regardless of age
./scripts/download_all_data.sh --force

# Using your own OpenAIP API key
./scripts/download_all_data.sh YOUR_API_KEY

# Force download with custom API key
./scripts/download_all_data.sh --force YOUR_API_KEY

# Show help
./scripts/download_all_data.sh --help
```

This will download all data types:
- Airports (from OpenAIP)
- Airspaces (from OpenAIP)
- Reporting points (from OpenAIP)
- Frequencies (from OurAirports)
- Navaids (from OurAirports)

**Note**: Data is only downloaded if it doesn't exist or is older than 24 hours. Use `--force` to download regardless of age.

### Download Individual Data Types

If you want to download only one type of data:

```bash
# Download only airports (using default key)
dart scripts/download_airports.dart

# Download only airspaces (using default key)
dart scripts/download_airspaces.dart

# Download only reporting points (using your own key)
dart scripts/download_reporting_points.dart --api-key YOUR_API_KEY

# Download frequencies from OurAirports
dart scripts/download_frequencies.dart

# Download navaids from OurAirports
dart scripts/download_navaids.dart
```

## Output Files

The scripts generate the following files in `assets/data/`:

- `airports.json` - All airports worldwide
- `airports.json.gz` - Compressed version
- `airspaces.json` - All airspaces worldwide
- `airspaces.json.gz` - Compressed version
- `reporting_points.json` - All reporting points worldwide
- `reporting_points.json.gz` - Compressed version
- `frequencies.json` - All airport frequencies worldwide
- `frequencies.json.gz` - Compressed version
- `navaids.json` - All navigation aids worldwide
- `navaids.json.gz` - Compressed version

## Integration

After downloading the data:

1. Compress the data: `dart scripts/prepare_compressed_data.dart`

2. Add the compressed files to your `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/data/airports_min.json.gz
       - assets/data/airspaces_min.json.gz
       - assets/data/reporting_points_min.json.gz
       - assets/data/frequencies_min.json.gz
       - assets/data/navaids_min.json.gz
   ```

2. The app will automatically load this bundled data on startup

3. The bundled data will be used as the primary source, reducing API calls

## Updating Data

Aviation data changes periodically (new airspaces, frequencies, etc.). 

### Manual Updates

```bash
# Check and update only outdated data (older than 24 hours)
./scripts/download_all_data.sh

# Force update all data
./scripts/download_all_data.sh --force
```

### Automatic Updates (Cron)

For automatic updates, use the `auto_update_data.sh` script:

```bash
# Add to crontab for daily updates at 3 AM
crontab -e
# Add this line:
0 3 * * * cd /path/to/captainvfr && ./scripts/auto_update_data.sh >> logs/data_update.log 2>&1
```

The auto-update script:
- Runs quietly unless there are updates or errors
- Only downloads data older than 24 hours
- Logs update activity with timestamps
- Use `--verbose` flag for detailed output

### Best Practices

1. Set up automatic daily updates via cron
2. Manually force update before major app releases
3. The download date is stored in each JSON file for reference
4. Monitor the log files for any download errors

## Resume Support

If the download is interrupted:
- The scripts save progress in `download_progress.json` files
- Simply run the script again and it will resume from where it left off
- Progress files are automatically cleaned up on successful completion

## Performance

- Each download takes approximately 10-30 minutes depending on your connection
- Airports file: ~30-50MB uncompressed, ~3-5MB compressed
- Airspaces file: ~50-100MB uncompressed, ~5-10MB compressed
- Reporting points file: ~10-30MB uncompressed, ~1-3MB compressed
- Frequencies file: ~5-10MB uncompressed, ~0.5-1MB compressed
- Navaids file: ~3-5MB uncompressed, ~0.3-0.5MB compressed
- Total compressed size: ~15-25MB (90% reduction)
- The scripts include rate limiting protection (60s wait on 429 errors)
- Age checking prevents unnecessary downloads (24-hour freshness window)

## Troubleshooting

1. **Rate limit errors**: The script automatically waits 60 seconds and retries
2. **Connection timeouts**: Re-run the script, it will resume from the last successful tile
3. **Invalid API key**: Check your API key at https://www.openaip.net/
4. **Disk space**: Ensure you have at least 200MB free space for the downloads