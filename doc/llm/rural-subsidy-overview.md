# Rural Subsidy System Overview

This document provides context for understanding the Australian rural subsidy system implemented in LocumTracker.

## Modified Monash Model (MMM) Classifications

The Modified Monash Model (MMM) classifies locations from MMM1 (metropolitan) to MMM7 (very remote) for rural subsidy eligibility.

### MMM Classifications
- **MMM1**: Major cities (≥1 million population)
- **MMM2**: Regional cities (50,000-1 million population)  
- **MMM3**: Large rural towns (15,000-50,000 population)
- **MMM4**: Medium rural towns (5,000-15,000 population)
- **MMM5**: Small rural towns (1,000-5,000 population)
- **MMM6**: Remote communities (<1,000 population, >1 hour from major service)
- **MMM7**: Very remote communities (<1,000 population, >2 hours from major service)

### Example Locations in App
- **Cooktown QLD 4895**: MMM6 classification
- **Dorrigo NSW 2453**: MMM5 classification

## Rural Subsidy Payment Rates

### Base Rates per Hour (2024 rates)
- **MMM3**: $0.00 per hour (no base subsidy)
- **MMM4**: $15.00 per hour
- **MMM5**: $25.00 per hour
- **MMM6**: $45.00 per hour
- **MMM7**: $65.00 per hour

### Vocational Status Multipliers
- **Vocational Doctors**: 100% of base rate
- **Non-Vocational Doctors**: 80% of base rate

### Quarterly Quota Requirements
- **Target**: 40 hours across MMM3-7 locations per quarter
- **Quota Deadlines**: March 31, June 30, September 30, December 31
- **Forfeiture**: Entire quarterly payment forfeited if quota not met

## Travel Time Credits

### Eligibility Rules
- **Travel Time Threshold**: Must exceed 1 hour (3600 seconds) to count
- **Documentation**: Travel time must be recorded and justifiable
- **Calculation**: Travel hours added to session hours for subsidy calculation

## Workforce Incentive Program (WIP) Doctor Stream

### Additional Financial Support
- **Practice Incentives**: Payments for established practices in MMM4-7 areas
- **Relocation Support**: Financial assistance for doctors moving to rural areas
- **Training Grants**: Support for professional development in rural medicine
- **Infrastructure Support**: Programs supporting rural healthcare facilities

### Eligibility Information
- **Full Documentation**: Available at https://www.doctorconnect.health/post/rural-doctor-incentives
- **Payment Calculators**: Tools to estimate potential earnings
- **Support Programs**: Various state and federal initiatives
- **Contact Details**: Doctor Connect service for personalized advice

## Key Resources for Doctors

### Government Resources
- **Health Workforce Locator**: https://www.health.gov.au/resources/apps-and-tools/health-workforce-locator
- **Department of Health**: State-specific rural health programs
- **Rural Health Multidisciplinary Teams**: Regional healthcare support networks
- **Medicare Provider Resources**: Practice support and incentives

### Application Process
- **Eligibility Assessment**: Based on practice location and population statistics
- **Application Forms**: Available through Doctor Connect portal
- **Timeline**: Processing typically takes 4-6 weeks for initial applications
- **Documentation Requirements**: Business plans, community needs, population demographics

## Important Notes

### Tax Implications
- **Taxable Income**: All WIP payments are considered taxable income
- **GST Considerations**: GST may apply depending on business structure
- **Record Keeping**: Essential for tax deductions and compliance
- **Professional Advice**: Consult with accountant familiar with rural practice incentives

### Professional Development
- **Training Opportunities**: Rural-focused continuing medical education
- **Research Support**: Access to rural health research programs
- **Networking**: Rural doctor conferences and professional associations
- **Mentorship**: Programs supporting rural doctor professional development

## Implementation in LocumTracker

### Data Model Integration
- **MMM Classification**: Built into Location model
- **Quarterly Quota**: Automatic tracking of MMM3-7 hours
- **Payment Calculations**: Integration with subsidy earnings
- **Progress Monitoring**: Real-time quota status and warnings
- **Reporting**: Export functions for compliance documentation

### User Experience
- **Automatic Classification**: MMM lookup by address/postcode
- **Quota Dashboard**: Visual progress tracking with warnings
- **Incentive Discovery**: Integration with Doctor Connect API
- **Compliance Reports**: Quarterly summaries for tax purposes

This system ensures that locum doctors can accurately track both their regular earnings and rural subsidy benefits, maximizing income through proper incentive participation.