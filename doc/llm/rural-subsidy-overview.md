# Rural Subsidy System Overview

This document provides context for understanding the Australian rural subsidy system implemented in LocumTracker.

## Modified Monash Model (MMM) Classifications

The Modified Monash Model (MMM) classifies locations from MMM1 (metropolitan) to MMM7 (very remote) for rural subsidy eligibility.

### MMM Classifications
- **MMM1**: Major cities 
- **MMM2**: Regional cities  
- **MMM3**: Large rural towns
- **MMM4**: Medium rural towns
- **MMM5**: Small rural towns
- **MMM6**: Remote communities 
- **MMM7**: Very remote communities 

### Example Locations in App
- **Cooktown QLD 4895**: MMM6 classification
- **Dorrigo NSW 2453**: MMM5 classification


### Quarterly Quota Requirements
- **Target**: minimum 21 sessions (minimum 3 hrs / session)  MMM3-7 locations per quarter
- **Quota Deadlines**: March 31, June 30, September 30, December 31
- **Forfeiture**: Entire quarterly payment forfeited if quota not met


## Workforce Incentive Program (WIP) Doctor Stream
https://www.health.gov.au/sites/default/files/2025-12/flexible-payment-system-application-form_0.docx


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