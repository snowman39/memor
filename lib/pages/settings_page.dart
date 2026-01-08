import 'package:flutter/material.dart';
import 'package:memor/services/completion_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _modelController = TextEditingController();
  bool _enabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureToken = true;

  // Test connection state
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiTokenController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await CompletionSettings.load();
    if (mounted) {
      setState(() {
        _baseUrlController.text = settings.baseUrl;
        _apiTokenController.text = settings.apiToken;
        _modelController.text = settings.model;
        _enabled = settings.enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final settings = CompletionSettings(
      baseUrl: _baseUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
      model: _modelController.text.trim(),
      enabled: _enabled,
    );

    try {
      await settings.save();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (_baseUrlController.text.trim().isEmpty ||
        _apiTokenController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty) {
      setState(() {
        _testResult = 'Please fill in all fields first';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final testSettings = CompletionSettings(
      baseUrl: _baseUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
      model: _modelController.text.trim(),
      enabled: true,
    );

    final service = CompletionService(testSettings);

    try {
      final startTime = DateTime.now();
      final result = await service
          .getCompletion('Hello, this is a test. Please respond with');
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (mounted) {
        setState(() {
          _isTesting = false;
          if (result != null && result.isNotEmpty) {
            _testSuccess = true;
            _testResult = 'Connected! Response in ${duration}ms';
          } else {
            _testSuccess = false;
            _testResult = 'Connected but no response received';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Autocomplete Section
              _buildSectionHeader('AI Autocomplete', colorScheme),
              const SizedBox(height: 16),

              // Enable/Disable toggle
              SwitchListTile(
                title: Text(
                  'Enable Autocomplete',
                  style: TextStyle(color: colorScheme.inversePrimary),
                ),
                subtitle: Text(
                  'Show AI-powered suggestions while typing',
                  style: TextStyle(
                    color: colorScheme.inversePrimary.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
                activeColor: colorScheme.primary,
              ),

              const SizedBox(height: 24),

              // API Configuration
              _buildSectionHeader('API Configuration', colorScheme),
              const SizedBox(height: 16),

              // Base URL
              TextFormField(
                controller: _baseUrlController,
                style: TextStyle(color: colorScheme.inversePrimary),
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                  helperText: 'OpenAI compatible API endpoint',
                  helperStyle: TextStyle(
                    color: colorScheme.inversePrimary.withOpacity(0.5),
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Base URL is required';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'Must start with http:// or https://';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // API Token
              TextFormField(
                controller: _apiTokenController,
                style: TextStyle(color: colorScheme.inversePrimary),
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  labelText: 'API Token',
                  hintText: 'sk-...',
                  helperText: 'Your API key (stored locally)',
                  helperStyle: TextStyle(
                    color: colorScheme.inversePrimary.withOpacity(0.5),
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                      color: colorScheme.inversePrimary.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureToken = !_obscureToken;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                style: TextStyle(color: colorScheme.inversePrimary),
                decoration: InputDecoration(
                  labelText: 'Model',
                  hintText: 'gpt-4o-mini',
                  helperText: 'Model name to use for completions',
                  helperStyle: TextStyle(
                    color: colorScheme.inversePrimary.withOpacity(0.5),
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Model is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Test Connection Section
              _buildSectionHeader('Test Connection', colorScheme),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.inversePrimary.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test your API configuration before saving',
                      style: TextStyle(
                        color: colorScheme.inversePrimary.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                              _isTesting ? 'Testing...' : 'Test Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                          ),
                        ),
                        if (_testResult != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _testSuccess == true
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _testSuccess == true
                                      ? Colors.green
                                      : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _testResult!,
                                    style: TextStyle(
                                      color: _testSuccess == true
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save button - 작은 크기로 중앙 정렬
              Center(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: colorScheme.inversePrimary,
      ),
    );
  }
}
