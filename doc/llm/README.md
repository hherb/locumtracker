# LLM Context for LocumTracker Development

This directory contains concise information for LLM context during development.

## Architecture Summary

- **Primary Purpose**: Invoicing and receipt management for locum doctors
- **Critical Feature**: Rural subsidy compliance (MMM classifications, quarterly quotas)
- **Platforms**: iOS + macOS with shared Swift packages
- **Tech Stack**: SwiftUI + SwiftData + CloudKit

## Key Data Models

- **Location**: MMM classification (1-7), address, coordinates
- **Assignment**: Rate structures (daily/hourly), date ranges, base location
- **DailyRecord**: Container for sessions, earnings, subsidies
- **Session**: Individual work periods with times, location, MMM classification
- **QuarterlyQuota**: MMM3-7 hours tracking for compliance
- **Receipt**: Expenses with image attachments

## Business Logic Rules

### Rural Subsidy Calculations
https://www.health.gov.au/sites/default/files/2025-12/flexible-payment-system-application-form_0.docx

### Rate Structures
- Default: Fixed daily rates (majority of placements)
- Alternative: Hourly rates + on-call + call-out + special rates
- Sessions: 1-n per day with start/end times
- Location overrides: Sessions can differ from assignment location

## Development Standards

- **Pure Functions**: Prefer pure, reusable functions
- **No Magic Numbers**: All constants defined and documented
- **Documentation**: Doc strings mandatory for public functions
- **Testing**: Unit tests mandatory for business logic

## CloudKit Configuration

- Container: `iCloud.com.hherb.locumtracker`
- Free tier limits: 1GB database, 250MB storage
- Sync: Automatic with SwiftData integration

## Example Data

- Cooktown QLD 4895: MMM6 classification
- Dorrigo NSW 2453: MMM5 classification

## Current Development Phase

Phase 1: Foundation - Core packages, data models, CloudKit integration