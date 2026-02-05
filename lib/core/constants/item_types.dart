import 'package:flutter/material.dart';

class FieldDefinition {
  final String key;
  final String label;
  final TextInputType keyboardType;
  final bool required;
  final bool obscure;
  final int maxLines;

  const FieldDefinition({
    required this.key,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.obscure = false,
    this.maxLines = 1,
  });
}

class ItemTypeDefinition {
  final String key;
  final String label;
  final IconData icon;
  final List<FieldDefinition> fields;

  const ItemTypeDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.fields,
  });
}

const List<ItemTypeDefinition> itemTypes = [
  ItemTypeDefinition(
    key: 'password',
    label: 'Password',
    icon: Icons.lock_outline,
    fields: [
      FieldDefinition(
        key: 'username',
        label: 'Username / Email',
        keyboardType: TextInputType.emailAddress,
        required: true,
      ),
      FieldDefinition(
        key: 'password',
        label: 'Password',
        obscure: true,
        required: true,
      ),
      FieldDefinition(
        key: 'notes',
        label: 'Notes',
        maxLines: 3,
      ),
    ],
  ),
  ItemTypeDefinition(
    key: 'bank',
    label: 'Bank Account',
    icon: Icons.account_balance,
    fields: [
      FieldDefinition(key: 'bank_name', label: 'Bank Name', required: true),
      FieldDefinition(
        key: 'account_number',
        label: 'Account Number',
        keyboardType: TextInputType.number,
        required: true,
      ),
      FieldDefinition(
        key: 'ifsc_code',
        label: 'IFSC Code',
        required: true,
      ),
      FieldDefinition(
        key: 'notes',
        label: 'Notes',
        maxLines: 3,
      ),
    ],
  ),
  ItemTypeDefinition(
    key: 'card',
    label: 'Card',
    icon: Icons.credit_card,
    fields: [
      FieldDefinition(
        key: 'number',
        label: 'Card Number',
        keyboardType: TextInputType.number,
        required: true,
      ),
      FieldDefinition(
        key: 'expiry',
        label: 'Expiry (MM/YY)',
        required: true,
      ),
      FieldDefinition(
        key: 'notes',
        label: 'Notes',
        maxLines: 3,
      ),
    ],
  ),
  ItemTypeDefinition(
    key: 'document',
    label: 'Document',
    icon: Icons.badge_outlined,
    fields: [
      FieldDefinition(
        key: 'scans',
        label: 'Scanned Pages',
      ),
      FieldDefinition(key: 'document_id', label: 'Document ID'),
      FieldDefinition(
        key: 'notes',
        label: 'Notes',
        maxLines: 3,
      ),
    ],
  ),
  ItemTypeDefinition(
    key: 'note',
    label: 'Secure Note',
    icon: Icons.note_alt_outlined,
    fields: [
      FieldDefinition(
        key: 'note',
        label: 'Note',
        maxLines: 6,
        required: true,
      ),
    ],
  ),
];

ItemTypeDefinition typeByKey(String key) {
  return itemTypes.firstWhere(
    (t) => t.key == key,
    orElse: () => itemTypes.first,
  );
}
