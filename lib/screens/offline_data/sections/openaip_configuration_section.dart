import 'package:flutter/material.dart';
import '../../../utils/form_theme_helper.dart';
import '../../../services/openaip_service.dart';

/// OpenAIP configuration section widget
class OpenAIPConfigurationSection extends StatelessWidget {
  final TextEditingController apiKeyController;
  final String openAIPApiKey;
  final Function(String) onSaveApiKey;
  final OpenAIPService openAIPService;

  const OpenAIPConfigurationSection({
    super.key,
    required this.apiKeyController,
    required this.openAIPApiKey,
    required this.onSaveApiKey,
    required this.openAIPService,
  });

  Future<void> _testApiKey(BuildContext context) async {
    if (apiKeyController.text.isEmpty) return;

    final nav = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Testing API Key',
        content: const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
    );
    
    try {
      openAIPService.setApiKey(apiKeyController.text);
      // Try to fetch a small amount of data to test the API key
      await openAIPService.getCachedAirspaces();
      nav.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('API key is valid!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      nav.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('API key test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormThemeHelper.buildSection(
      title: 'OpenAIP Configuration',
      children: [
        FormThemeHelper.buildFormField(
          controller: apiKeyController,
          labelText: 'API Key',
          hintText: 'Enter your OpenAIP API key',
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => onSaveApiKey(apiKeyController.text),
              style: FormThemeHelper.getPrimaryButtonStyle(),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _testApiKey(context),
              style: FormThemeHelper.getOutlinedButtonStyle(),
              child: const Text('Test API Key'),
            ),
          ],
        ),
        if (openAIPApiKey.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Auto-loading of airspaces and reporting points enabled',
            style: TextStyle(
              fontSize: 12,
              color: FormThemeHelper.secondaryTextColor,
            ),
          ),
        ],
      ],
    );
  }
}