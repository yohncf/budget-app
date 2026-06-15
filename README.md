# Budget App

A Personal Finance & Budget App designed to track expenses, salary, investments, and net worth. 

## Technical Architecture

- **Frontend:** Flutter Web (Dart)
- **Database (Primary):** Firebase Firestore
- **Database (Backup):** Supabase (PostgreSQL)
- **Data Integration & Audit Ledger:** Google Sheets + Google Apps Script

## Core Architecture Documents

- [Antigravity Instructions](Antigravity_Instructions.md): Hard business logic, rules, and synchronization invariants.
- [Database Schema Blueprint](DataBaseSchemaBlueprint.md): Structured tables description, fields, and constraints.
- [database_schema.json](database_schema.json): Machine-readable JSON schema.

## Getting Started

1. Set up the Flutter SDK.
2. Initialize Firebase and Supabase.
3. Configure the Apps Script synchronization engine with Google Sheets.
