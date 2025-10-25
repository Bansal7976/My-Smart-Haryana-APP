import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/language_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/web_compatible_image.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../services/api_service.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  File? _selectedImage;
  String? _selectedProblemType;
  double? _latitude;
  double? _longitude;
  String? _currentAddress;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  final List<String> _problemTypes = [
    'Pothole',
    'Street Light',
    'Water Supply',
    'Sewage',
    'Road Repair',
    'Cleaning',
    'Electrical',
    'Drainage',
    'Public Transport',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startStopRecording() async {
    if (_isRecording) {
      // Stop recording
      await _stopRecording();
    } else {
      // Start recording
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          _showErrorDialog('Microphone permission denied');
        }
        return;
      }

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText('Recording...', 'रिकॉर्डिंग...')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to start recording: ${e.toString()}');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (path != null) {
        // Convert audio to text
        await _transcribeAudio(path);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      _showErrorDialog('Failed to stop recording: ${e.toString()}');
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      // Convert to text using API
      final result = await ApiService.convertVoiceToText(
        authProvider.token!,
        File(audioPath),
        language: languageProvider.currentLanguage == 'hi' ? 'hi-IN' : 'en-IN',
      );

      if (!mounted) return;

      if (result['text'] != null && result['text'].isNotEmpty) {
        setState(() {
          // Append to existing description
          if (_descriptionController.text.isNotEmpty) {
            _descriptionController.text += ' ${result['text']}';
          } else {
            _descriptionController.text = result['text'];
          }
        });

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                'Voice converted to text successfully!',
                'आवाज सफलतापूर्वक टेक्स्ट में परिवर्तित हुई!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to convert voice: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorDialog(
              'Location services are disabled. Please enable location services.');
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showErrorDialog(
                'Location permissions are denied. Please allow location access.');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showErrorDialog(
              'Location permissions are permanently denied. Please enable in settings.');
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Get address from coordinates
      try {
        // You can use geocoding package here to get address
        // For now, we'll just show coordinates
        _currentAddress =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _locationController.text = _currentAddress!;
      } catch (e) {
        _currentAddress =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _locationController.text = _currentAddress!;
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Location captured successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to get location: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          // For web compatibility, we need to handle the file differently
          if (kIsWeb) {
            // On web, create a File from the XFile path
            _selectedImage = File(image.path);
          } else {
            // On mobile/desktop, use the path directly
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_selectedProblemType == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText('Please select a problem type',
                  'कृपया समस्या का प्रकार चुनें')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedImage == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText('Please select an image', 'कृपया एक छवि चुनें')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token available');
      }

      if (authProvider.user?.district == null) {
        throw Exception('User district not available');
      }

      final success = await issueProvider.addIssue(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedProblemType!,
        authProvider.user!.district!,
        _latitude ?? 0.0,
        _longitude ?? 0.0,
        _selectedImage!,
        authProvider.token!,
      );

      if (!mounted) return;

      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                      'Issue reported successfully!',
                      'समस्या सफलतापूर्वक रिपोर्ट की गई!')),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                '${languageProvider.getText('Failed to submit issue', 'समस्या सबमिट करने में असफल')}: ${issueProvider.error ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to submit issue: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Report Issue', 'समस्या रिपोर्ट करें'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field
              CustomTextField(
                controller: _titleController,
                label:
                    languageProvider.getText('Issue Title', 'समस्या का शीर्षक'),
                hint: languageProvider.getText(
                    'Enter a brief title', 'एक संक्षिप्त शीर्षक दर्ज करें'),
                prefixIcon: Icons.title,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.getText(
                        'Please enter a title', 'कृपया एक शीर्षक दर्ज करें');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description Field with Voice Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText('Description', 'विवरण'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: languageProvider.getText(
                            'Describe the issue in detail',
                            'समस्या का विस्तार से वर्णन करें'),
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.description,
                            color: AppColors.textSecondary),
                        suffixIcon: _isTranscribing
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: _isRecording ? Colors.red : AppColors.primary,
                                ),
                                onPressed: _startStopRecording,
                                tooltip: _isRecording
                                    ? languageProvider.getText(
                                        'Stop Recording', 'रिकॉर्डिंग बंद करें')
                                    : languageProvider.getText(
                                        'Start Voice Input', 'आवाज इनपुट शुरू करें'),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getText(
                              'Please enter a description',
                              'कृपया एक विवरण दर्ज करें');
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: Colors.red, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            languageProvider.getText(
                                'Recording... Tap mic to stop',
                                'रिकॉर्डिंग... रोकने के लिए माइक पर टैप करें'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Problem Type Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText(
                        'Problem Type', 'समस्या का प्रकार'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedProblemType,
                      decoration: InputDecoration(
                        hintText: languageProvider.getText(
                            'Select problem type', 'समस्या का प्रकार चुनें'),
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.category_outlined,
                            color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      items: _problemTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProblemType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getText(
                              'Please select a problem type',
                              'कृपया समस्या का प्रकार चुनें');
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location Section
              Text(
                languageProvider.getText('Location', 'स्थान'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              // Location Field
              CustomTextField(
                controller: _locationController,
                label: languageProvider.getText('Location', 'स्थान'),
                hint: languageProvider.getText('Tap to get current location',
                    'वर्तमान स्थान प्राप्त करने के लिए टैप करें'),
                prefixIcon: Icons.location_on,
                readOnly: true,
                onTap: _getCurrentLocation,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.getText('Please get your location',
                        'कृपया अपना स्थान प्राप्त करें');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Get Location Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isGettingLocation
                        ? languageProvider.getText('Getting Location...',
                            'स्थान प्राप्त कर रहे हैं...')
                        : languageProvider.getText('Get Current Location',
                            'वर्तमान स्थान प्राप्त करें'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Image Upload Section
              Text(
                languageProvider.getText('Photo (Required)', 'फोटो (आवश्यक)'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              // Image Preview and Upload Button
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: WebCompatibleImage(
                              file: _selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              languageProvider.getText(
                                  'No image selected', 'कोई छवि चयनित नहीं'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              // Upload Image Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload),
                  label: Text(
                    languageProvider.getText('Upload Image', 'छवि अपलोड करें'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: languageProvider.getText(
                    'Submit Issue', 'समस्या सबमिट करें'),
                onPressed: _isLoading ? null : _submitIssue,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

