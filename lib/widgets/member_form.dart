import 'package:flutter/material.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/screens/consent_screen.dart';

class MemberForm extends StatefulWidget {
  final Member? existingMember;
  final ClubController controller;
  final Function(Member) onSubmit;

  const MemberForm({
    super.key,
    this.existingMember,
    required this.controller,
    required this.onSubmit,
  });

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
  final _heardAboutController = TextEditingController();
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
  String? _consentSignaturePath;
  String? _consentPhotoPath;
  DateTime? _consentDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingMember != null) {
      final m = widget.existingMember!;
      _firstNameController.text = m.firstName;
      _lastNameController.text = m.lastName;
      _addressController.text = m.address;
      _emailController.text = m.email;
      _mobileController.text = m.mobile;
      _homePhoneController.text = m.homePhone;
      _emergencyContactController.text = m.emergencyContact;
      _suspendedDetailsController.text = m.suspendedDetails ?? "";
      _heardAboutController.text = m.heardAbout;
      _legalGuardianController.text = m.legalGuardian ?? "";
      
      _selectedDob = m.dob;
      _hasBeenSuspended = m.hasBeenSuspended;
      _consentSigned = m.consentSigned;
      _consentSignaturePath = m.consentSignaturePath;
      _consentPhotoPath = m.consentPhotoPath;
      _consentDate = m.consentDate;

      final med = m.medicalHistory;
      _backInjury = med.backInjury;
      _hernia = med.hernia;
      _epilepsy = med.epilepsy;
      _allergies = med.allergies;
      _heartCondition = med.heartCondition;
      _physicalDisability = med.physicalDisability;
      _asthma = med.asthma;
      _psychological = med.psychological;
      _otherMedical = med.other;
      _otherMedicalDetailsController.text = med.otherDetails ?? "";
    }
  }

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
                    required: false,
                  ),
                ),
              ],
            ),
            _buildTextField(_addressController, "Address", required: false),
            _buildTextField(
              _emailController,
              "Email",
              required: false,
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
                required: false,
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
                required: false,
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
                required: false,
              ),

            _buildTextField(
              _heardAboutController,
              "Where did you hear about Yoseikan Budo?",
              required: false,
            ), // "where did you hear..."

            const SizedBox(height: 16),
            if (_consentSigned || _consentSignaturePath != null)
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.green),
                title: const Text("Consent Document Signed"),
                subtitle: Text("Signed on: ${_consentDate != null ? _consentDate!.toIso8601String().split('T').first : 'Unknown Date'}"),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.draw),
                  label: const Text("Sign Consent Document"),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConsentScreen(documentText: widget.controller.consentDocumentText),
                      ),
                    );
                    if (result != null && result is Map) {
                      setState(() {
                        _consentSigned = true;
                        _consentSignaturePath = result['signaturePath'];
                        _consentPhotoPath = result['photoPath'];
                        _consentDate = result['date'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Consent signed successfully!")),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.blueAccent,
                  ),
                ),
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

      final member = widget.existingMember != null
          ? Member(
              id: widget.existingMember!.id,
              firstName: _firstNameController.text,
              lastName: _lastNameController.text,
              address: _addressController.text,
              email: _emailController.text,
              dob: _selectedDob ?? DateTime.now(),
              mobile: _mobileController.text,
              homePhone: _homePhoneController.text,
              emergencyContact: _emergencyContactController.text,
              medicalHistory: medicalHistory,
              hasBeenSuspended: _hasBeenSuspended,
              suspendedDetails: _hasBeenSuspended ? _suspendedDetailsController.text : null,
              heardAbout: _heardAboutController.text,
              legalGuardian: _isUnder18() ? _legalGuardianController.text : null,
              consentSigned: _consentSigned,
              consentSignaturePath: _consentSignaturePath,
              consentPhotoPath: _consentPhotoPath,
              consentDate: _consentDate,
              consentDocText: widget.controller.consentDocumentText,
              familyGroupId: widget.existingMember!.familyGroupId,
              balance: widget.existingMember!.balance,
            )
          : Member.create(
              firstName: _firstNameController.text,
              lastName: _lastNameController.text,
              address: _addressController.text,
              email: _emailController.text,
              dob: _selectedDob ?? DateTime.now(),
              mobile: _mobileController.text,
              homePhone: _homePhoneController.text,
              emergencyContact: _emergencyContactController.text,
              medicalHistory: medicalHistory,
              hasBeenSuspended: _hasBeenSuspended,
              suspendedDetails: _hasBeenSuspended ? _suspendedDetailsController.text : null,
              heardAbout: _heardAboutController.text,
              legalGuardian: _isUnder18() ? _legalGuardianController.text : null,
              consentSigned: _consentSigned,
              consentSignaturePath: _consentSignaturePath,
              consentPhotoPath: _consentPhotoPath,
              consentDate: _consentDate,
              consentDocText: widget.controller.consentDocumentText,
            );

      widget.onSubmit(member);
    }
  }
}
