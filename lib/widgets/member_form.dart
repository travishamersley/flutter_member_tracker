import 'package:flutter/material.dart';
import 'package:membership_tracker/models.dart';

class MemberForm extends StatefulWidget {
  final Function(
    String firstName,
    String lastName,
    String address,
    String email,
    DateTime dob,
    String mobile,
    String homePhone,
    String emergencyContact,
    MedicalHistory medicalHistory,
    bool hasBeenSuspended,
    String? suspendedDetails,
    String heardAbout,
    String? legalGuardian,
    bool consentSigned,
  )
  onSubmit;

  const MemberForm({super.key, required this.onSubmit});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _homePhoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _suspendedDetailsController = TextEditingController();
  final _heardAboutController = TextEditingController(); // Or dropdown?
  final _legalGuardianController = TextEditingController();
  final _otherMedicalDetailsController = TextEditingController();

  DateTime? _selectedDob;

  // Flags
  bool _backInjury = false;
  bool _hernia = false;
  bool _epilepsy = false;
  bool _allergies = false;
  bool _heartCondition = false;
  bool _physicalDisability = false;
  bool _asthma = false;
  bool _psychological = false;
  bool _otherMedical = false;

  bool _hasBeenSuspended = false;
  bool _consentSigned = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Personal Details"),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _firstNameController,
                    "First Name",
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    _lastNameController,
                    "Surname",
                    required: true,
                  ),
                ),
              ],
            ),
            _buildTextField(_addressController, "Address", required: true),
            _buildTextField(
              _emailController,
              "Email",
              required: true,
              email: true,
            ),

            // DOB Picker
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date of Birth *",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDob != null
                        ? "${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}"
                        : "Select Date",
                  ),
                ),
              ),
            ),
            if (_isUnder18())
              _buildTextField(
                _legalGuardianController,
                "Legal Parent/Guardian",
                required: true,
              ),

            _sectionHeader("Contact Info"),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _mobileController,
                    "Mobile",
                    required: false,
                  ),
                ), // User req said Mobile? "Mobile, home"
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(_homePhoneController, "Home Phone"),
                ),
              ],
            ),
            _buildTextField(
              _emergencyContactController,
              "Emergency Contact Details",
              required: false,
            ), // "emergecny contact details"

            _sectionHeader("Medical History"),
            Wrap(
              spacing: 8.0,
              children: [
                _buildCheckbox(
                  "Back Injury",
                  _backInjury,
                  (v) => setState(() => _backInjury = v!),
                ),
                _buildCheckbox(
                  "Hernia",
                  _hernia,
                  (v) => setState(() => _hernia = v!),
                ),
                _buildCheckbox(
                  "Epilepsy",
                  _epilepsy,
                  (v) => setState(() => _epilepsy = v!),
                ),
                _buildCheckbox(
                  "Allergies",
                  _allergies,
                  (v) => setState(() => _allergies = v!),
                ),
                _buildCheckbox(
                  "Heart Condition",
                  _heartCondition,
                  (v) => setState(() => _heartCondition = v!),
                ),
                _buildCheckbox(
                  "Physical Disability",
                  _physicalDisability,
                  (v) => setState(() => _physicalDisability = v!),
                ),
                _buildCheckbox(
                  "Asthma",
                  _asthma,
                  (v) => setState(() => _asthma = v!),
                ),
                _buildCheckbox(
                  "Psychological",
                  _psychological,
                  (v) => setState(() => _psychological = v!),
                ),
                _buildCheckbox(
                  "Other",
                  _otherMedical,
                  (v) => setState(() => _otherMedical = v!),
                ),
              ],
            ),
            if (_otherMedical)
              _buildTextField(
                _otherMedicalDetailsController,
                "Other Medical Details",
                required: true,
              ),

            _sectionHeader("Other Information"),
            SwitchListTile(
              title: const Text(
                "Have you ever been suspended, expelled or refused admission to any Martial Arts Organisation?",
              ),
              value: _hasBeenSuspended,
              onChanged: (val) => setState(() => _hasBeenSuspended = val),
            ),
            if (_hasBeenSuspended)
              _buildTextField(
                _suspendedDetailsController,
                "Details of suspension/refusal",
                required: true,
              ),

            _buildTextField(
              _heardAboutController,
              "Where did you hear about Yoseikan Budo?",
              required: false,
            ), // "where did you hear..."

            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                "I have read and signed the informed consent and participation commitment form.",
              ),
              value: _consentSigned,
              onChanged: (val) => setState(() => _consentSigned = val!),
              subtitle: _consentSigned
                  ? null
                  : const Text("Required", style: TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text("Save Member"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool email = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label + (required ? " *" : ""),
          border: const OutlineInputBorder(),
        ),
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return "Required";
          }
          if (email &&
              value != null &&
              value.isNotEmpty &&
              !value.contains('@')) {
            return "Invalid email";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (bool selected) {
        onChanged(selected);
      },
      checkmarkColor: Colors.white,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  bool _isUnder18() {
    if (_selectedDob == null) return false;
    final now = DateTime.now();
    var age = now.year - _selectedDob!.year;
    if (now.month < _selectedDob!.month ||
        (now.month == _selectedDob!.month && now.day < _selectedDob!.day)) {
      age--;
    }
    return age < 18;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Date of Birth")),
        );
        return;
      }
      if (!_consentSigned) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Consent must be signed")));
        return;
      }

      final medicalHistory = MedicalHistory(
        backInjury: _backInjury,
        hernia: _hernia,
        epilepsy: _epilepsy,
        allergies: _allergies,
        heartCondition: _heartCondition,
        physicalDisability: _physicalDisability,
        asthma: _asthma,
        psychological: _psychological,
        other: _otherMedical,
        otherDetails: _otherMedical
            ? _otherMedicalDetailsController.text
            : null,
      );

      widget.onSubmit(
        _firstNameController.text,
        _lastNameController.text,
        _addressController.text,
        _emailController.text,
        _selectedDob!,
        _mobileController.text,
        _homePhoneController.text,
        _emergencyContactController.text,
        medicalHistory,
        _hasBeenSuspended,
        _hasBeenSuspended ? _suspendedDetailsController.text : null,
        _heardAboutController.text,
        _isUnder18() ? _legalGuardianController.text : null,
        _consentSigned,
      );
    }
  }
}
