# Workforce Incentive Program (WIP) - Doctor Stream
## Flexible Payment System (FPS) Rules for Subsidy Tracking

**Last Updated:** January 2024  
**Program:** WIP Doctor Stream - Flexible Payment System  
**Target:** Rural and Remote Doctors (MMM 3-7)

---

## 1. ELIGIBILITY CRITERIA

### 1.1 Location Requirements
- **Eligible Locations:** Modified Monash Model (MMM) categories 3, 4, 5, 6, or 7
- **Location Verification:** Use Health Workforce Locator (https://www.health.gov.au/resources/apps-and-tools/health-workforce-locator)
- **Not Eligible:** MMM 1-2 locations (except for specific training placements - see section 1.4)

### 1.2 Service Requirements
Must provide ONE of the following:
1. Eligible primary care services (MBS or non-MBS)
2. Eligible GP/Rural Generalist training under approved pathway

### 1.3 Registration Status Categories
```
CATEGORY_VR: Vocationally Registered Doctor
CATEGORY_TRAINING: Non-VR on approved training pathway
CATEGORY_NON_VR: Non-VR not on approved training pathway (receives 80% of VR payment)
```

### 1.4 Approved Training Pathways
- Australian General Practice Training Program (AGPT) - RACGP or ACRRM
- Rural Generalist Training Scheme (RGTS)
- Remote Vocational Training Scheme (RVTS)
- Advanced Specialised Training (ACRRM) in MMM 1-2 (requires RTO authorization)
- Additional Rural Skills (RACGP) in MMM 1-2 (requires GP College authorization)

---

## 2. ACTIVITY MEASUREMENT

### 2.1 Session Definition (FPS)
```
SESSION_MINIMUM_DURATION: 3 hours continuous
SESSION_MAXIMUM_PER_DAY: 2
SESSION_TYPES:
  - Eligible primary care services (MBS or non-MBS)
  - Eligible GP/RG training
```

### 2.2 Quarterly Activity Thresholds
```
QUARTER_MINIMUM_SESSIONS: 21
QUARTER_MAXIMUM_SESSIONS: 104 (sessions above this threshold not counted)
QUARTER_MINIMUM_MBS: $6,000 (for CPS comparison)
QUARTER_MAXIMUM_MBS: $30,000 (for CPS comparison)
```

### 2.3 Active Quarter Definition
A quarter becomes ACTIVE when:
```
FPS_ACTIVE = sessions >= 21 AND each_session >= 3_hours
```

**Important:** Excess sessions above 104 per quarter do NOT carry forward to other quarters.

---

## 3. PAYMENT QUALIFICATION PERIODS

### 3.1 Reference Periods by Location

#### New Participants
```
MMM_3_4_5:
  active_quarters_required: 8
  reference_period_quarters: 16
  initial_payment_year_level: 2

MMM_6_7:
  active_quarters_required: 4
  reference_period_quarters: 8
  initial_payment_year_level: 1
```

#### Continuing Participants (All MMM)
```
CONTINUING:
  active_quarters_required: 4
  reference_period_quarters: 8
```

### 3.2 Quarter Tracking Rules
- Reference period = rolling window
- Can have gaps (inactive quarters) within reference period
- Only active quarters count toward threshold
- Missing occasional quarters is acceptable if minimum met within reference period

---

## 4. PAYMENT AMOUNTS

### 4.1 Payment Matrix - Vocationally Registered (VR) or On Approved Training Pathway

| Year Level | MMM 3 | MMM 4 | MMM 5 | MMM 6 | MMM 7 |
|------------|-------|-------|-------|-------|-------|
| Year 1 | $4,500 | $7,500 | $12,000 | $25,000 | $47,000 |
| Year 2 | $7,500 | $12,000 | $15,000 | $30,000 | $50,000 |
| Year 3 | $10,000 | $15,000 | $18,000 | $35,000 | $55,000 |
| Year 4+ | $12,000 | $18,000 | $21,000 | $40,000 | $60,000 |

### 4.2 Payment Matrix - Non-VR NOT on Approved Training Pathway (80% of VR)

| Year Level | MMM 3 | MMM 4 | MMM 5 | MMM 6 | MMM 7 |
|------------|-------|-------|-------|-------|-------|
| Year 1 | $3,600 | $6,000 | $9,600 | $20,000 | $37,600 |
| Year 2 | $6,000 | $9,600 | $12,000 | $24,000 | $40,000 |
| Year 3 | $8,000 | $12,000 | $14,400 | $28,000 | $44,000 |
| Year 4+ | $9,600 | $14,400 | $16,800 | $32,000 | $48,000 |

### 4.3 Year Level Progression
```
YEAR_LEVEL_CALCULATION:
  year_1: first payment period
  year_2: after first payment received
  year_3: after second payment received
  year_4_plus: after third payment received (remains at year 4+ thereafter)
```

---

## 5. FPS APPLICATION SCENARIOS

### 5.1 Primary FPS Use Cases

#### Scenario A: Non-MBS Services Only
```
APPLIES_TO:
  - State salaried medical practitioners (MM6-7 only)
  - Hospital procedural services to private patients (MM6-7 only)
  - Services not billed to MBS
  
REQUIREMENT: Apply via FPS for all eligible sessions
```

#### Scenario B: Training Registrars
```
APPLIES_TO:
  - GP Registrars on approved training pathways
  - Training placements MMM 3-7
  - Selected MMM 1-2 placements (with RTO/College authorization)
  
REQUIREMENT: RTO/College verification of training sessions
```

#### Scenario C: Top-Up Payment (Mixed MBS + Non-MBS)
```
APPLIES_TO:
  - Already receiving CPS automatic payment
  - Provided additional eligible non-MBS services
  - OR meets special top-up provisions (MM6-7)
  
REQUIREMENT: Apply via FPS for non-MBS component only
```

#### Scenario D: Special Top-Up Provisions (MM6-7 only)
```
ELIGIBLE_ACTIVITIES:
  - Excessive travel time: ≥3 cumulative hours/week ABOVE initial 3 hours/week
  - Population health work in Aboriginal communities
  - Essential services to relatively small community
  - Support to Aboriginal health workers
  - Outreach services requiring excessive travel
  
REQUIREMENT: Evidence of qualifying activities
```

### 5.2 Services NOT Eligible for FPS
```
INELIGIBLE:
  - State salaried medical practitioners in MMM 1-5
  - Compulsory hospital year (RACGP or ACRRM core training)
  - Non-Advanced Specialised Training hospital work
  - Australian Defence facilities
  - Services outside MMM 3-7 (except authorized training placements)
```

---

## 6. DOCUMENTATION REQUIREMENTS

### 6.1 Standard FPS Application
```
REQUIRED_DOCUMENTS:
  1. Completed FPS Application Form (paper-based, handwritten signature required)
  2. Session log showing:
     - Date of each session
     - Location (MMM classification)
     - Duration (must be ≥3 hours)
     - Type of service/training
  3. Bank account details (if not already on file)
  4. Employment verification (if applicable)
```

### 6.2 Additional Documentation by Scenario

#### For Training Registrars
```
ADDITIONAL_REQUIRED:
  - RTO/GP College verification of training sessions
  - Training placement authorization (if MMM 1-2)
```

#### For Alternative Employment/Top-Up
```
ADDITIONAL_REQUIRED:
  - Evidence of non-MBS services
  - Payslips or employment contract (if salaried)
  - Service delivery records
```

#### For Special Top-Up (MM6-7)
```
ADDITIONAL_REQUIRED:
  - Travel logs (for excessive travel claim)
  - Community size documentation
  - Aboriginal health worker support records
  - Population health activity records
```

---

## 7. APPLICATION PROCESS

### 7.1 Submission
```
SUBMIT_TO: Rural Workforce Agency (RWA) in state/territory where most services provided

STATE_RWA_CONTACTS:
  NSW: Rural Doctors Network (RDN)
  VIC: Rural Workforce Agency Victoria (RWAV)
  QLD: Health Workforce Queensland
  SA: Rural Doctors Workforce Agency (RDWA)
  WA: Rural Health West
  TAS: Rural Health Tasmania
  NT: Northern Territory Primary Health Network
  ACT: Services via NSW RDN
```

### 7.2 Timing
```
APPLICATION_TIMING:
  - Can apply after completing required active quarters
  - Apply quarterly or accumulate multiple quarters
  - Payment processed after submission and verification
```

### 7.3 Bank Details
```
BANK_DETAILS_REQUIRED:
  - Must be provided within 60 days of Services Australia notification
  - Can be provided on FPS form OR directly to Services Australia
  - Payment lapses if not provided within timeframe
```

---

## 8. CALCULATION ALGORITHM FOR APPS

### 8.1 Pseudocode for Payment Calculation

```python
def calculate_wip_payment(doctor_profile, work_history):
    """
    Calculate WIP Doctor Stream FPS payment entitlement
    
    Args:
        doctor_profile: {
            'registration_status': 'VR' | 'TRAINING' | 'NON_VR',
            'approved_training_pathway': bool
        }
        work_history: [
            {
                'quarter': 'YYYY-Q#',
                'mmm_level': 3-7,
                'sessions': int,  # number of 3+ hour sessions
                'session_details': [...] 
            }
        ]
    
    Returns:
        {
            'eligible': bool,
            'payment_amount': float,
            'year_level': int,
            'mmm_level': int,
            'active_quarters': int,
            'payment_history': [...]
        }
    """
    
    # Step 1: Determine registration multiplier
    if doctor_profile['registration_status'] == 'VR' or doctor_profile['approved_training_pathway']:
        payment_multiplier = 1.0
    else:
        payment_multiplier = 0.8
    
    # Step 2: Identify active quarters
    active_quarters = []
    for quarter in work_history:
        if quarter['sessions'] >= 21 and quarter['mmm_level'] in [3,4,5,6,7]:
            active_quarters.append(quarter)
    
    # Step 3: Check if eligible based on location and reference period
    if not active_quarters:
        return {'eligible': False, 'reason': 'No active quarters'}
    
    # Determine predominant MMM level (where most services provided)
    mmm_mode = most_common([q['mmm_level'] for q in active_quarters])
    
    # Step 4: Check reference period requirements
    is_new_participant = check_if_new_participant(payment_history)
    
    if is_new_participant:
        if mmm_mode in [3,4,5]:
            required_quarters = 8
            reference_period = 16
            initial_year_level = 2
        else:  # MMM 6-7
            required_quarters = 4
            reference_period = 8
            initial_year_level = 1
        
        # Check last N quarters
        recent_quarters = active_quarters[-reference_period:]
        if len(recent_quarters) < required_quarters:
            return {
                'eligible': False, 
                'reason': f'Need {required_quarters} active quarters in last {reference_period} quarters',
                'current_active': len(recent_quarters),
                'quarters_needed': required_quarters - len(recent_quarters)
            }
    else:
        # Continuing participant
        recent_quarters = active_quarters[-8:]
        if len(recent_quarters) < 4:
            return {
                'eligible': False,
                'reason': 'Need 4 active quarters in last 8 quarters',
                'current_active': len(recent_quarters)
            }
    
    # Step 5: Calculate year level
    year_level = calculate_year_level(payment_history, is_new_participant, initial_year_level)
    
    # Step 6: Look up base payment amount
    payment_matrix_vr = {
        1: {3: 4500, 4: 7500, 5: 12000, 6: 25000, 7: 47000},
        2: {3: 7500, 4: 12000, 5: 15000, 6: 30000, 7: 50000},
        3: {3: 10000, 4: 15000, 5: 18000, 6: 35000, 7: 55000},
        4: {3: 12000, 4: 18000, 5: 21000, 6: 40000, 7: 60000}
    }
    
    base_payment = payment_matrix_vr[year_level][mmm_mode]
    final_payment = base_payment * payment_multiplier
    
    return {
        'eligible': True,
        'payment_amount': final_payment,
        'year_level': year_level,
        'mmm_level': mmm_mode,
        'active_quarters': len(active_quarters),
        'registration_status': doctor_profile['registration_status'],
        'multiplier': payment_multiplier
    }


def calculate_year_level(payment_history, is_new_participant, initial_year_level=1):
    """Calculate current year level based on payment history"""
    if is_new_participant:
        return initial_year_level
    
    payments_received = len(payment_history)
    
    if payments_received == 0:
        return 1
    elif payments_received == 1:
        return 2
    elif payments_received == 2:
        return 3
    else:  # 3+
        return 4


def validate_session(session_detail):
    """Validate individual session meets FPS requirements"""
    requirements = {
        'minimum_duration_hours': 3,
        'mmm_valid': session_detail['mmm'] in [3,4,5,6,7],
        'service_eligible': check_service_eligibility(session_detail),
    }
    return all(requirements.values())


def check_service_eligibility(session_detail):
    """Check if service type is eligible for FPS"""
    eligible_types = [
        'primary_care_non_mbs',
        'approved_training',
        'hospital_procedural_mm6_7',
        'salaried_primary_care_mm6_7',
        'special_top_up_activities'
    ]
    return session_detail['service_type'] in eligible_types
```

### 8.2 Session Validation Rules

```python
def validate_quarter_sessions(sessions):
    """
    Validate sessions for a quarter
    Returns: (is_active_quarter, counted_sessions, validation_errors)
    """
    
    errors = []
    valid_sessions = []
    
    # Group by date
    sessions_by_date = group_by_date(sessions)
    
    for date, day_sessions in sessions_by_date.items():
        # Rule: Maximum 2 sessions per day
        if len(day_sessions) > 2:
            errors.append(f"More than 2 sessions claimed on {date}")
            day_sessions = day_sessions[:2]  # Take first 2
        
        for session in day_sessions:
            # Rule: Minimum 3 hours per session
            if session['duration_hours'] < 3:
                errors.append(f"Session on {date} less than 3 hours")
                continue
            
            # Rule: Valid MMM location
            if session['mmm_level'] not in [3,4,5,6,7]:
                # Check if authorized training in MMM 1-2
                if not (session['mmm_level'] in [1,2] and 
                       session['authorized_training']):
                    errors.append(f"Invalid MMM location on {date}")
                    continue
            
            valid_sessions.append(session)
    
    counted_sessions = len(valid_sessions)
    
    # Cap at maximum threshold
    if counted_sessions > 104:
        errors.append(f"Sessions capped at 104 (claimed {counted_sessions})")
        counted_sessions = 104
    
    is_active = counted_sessions >= 21
    
    return (is_active, counted_sessions, errors)
```

---

## 9. SPECIAL CONSIDERATIONS FOR LOCUM DOCTORS

### 9.1 Locum-Specific Rules
```
MULTI_LOCATION_WORK:
  - Track sessions by MMM level for each quarter
  - Payment based on predominant MMM level (where most services provided)
  - Can work in multiple MMM locations within same quarter
  - Submit to RWA in state where MOST services provided

INTERMITTENT_WORK:
  - Active quarters need not be consecutive
  - Reference period is rolling window
  - Missing quarters OK if minimum active quarters met within reference period
  - Each quarter evaluated independently for 21+ sessions
```

### 9.2 Common Locum Patterns

#### Pattern 1: Rotating Through Multiple Sites
```
EXAMPLE:
  Q1: 15 sessions MMM4 + 10 sessions MMM6 = 25 total → ACTIVE, classify as MMM4
  Q2: 8 sessions MMM3 + 18 sessions MMM5 = 26 total → ACTIVE, classify as MMM5
  Q3: 5 sessions MMM4 = 5 total → INACTIVE (below minimum)
  Q4: 30 sessions MMM6 → ACTIVE, classify as MMM6

RESULT: 3 active quarters in 4-quarter period
```

#### Pattern 2: Seasonal Work (e.g., Summer/Winter)
```
EXAMPLE (MM6-7 doctor):
  Q1: 0 sessions → INACTIVE
  Q2: 35 sessions MMM7 → ACTIVE
  Q3: 28 sessions MMM7 → ACTIVE
  Q4: 0 sessions → INACTIVE
  Q5: 0 sessions → INACTIVE
  Q6: 40 sessions MMM7 → ACTIVE
  Q7: 32 sessions MMM7 → ACTIVE
  Q8: 0 sessions → INACTIVE

RESULT: 4 active quarters in 8-quarter window → ELIGIBLE for continuing payment
```

### 9.3 Documentation Tips for Locums
```
MAINTAIN_RECORDS:
  - Log every session with date, location (town + MMM), duration
  - Keep contracts/agreements from each placement
  - Document travel times if claiming special top-up (MM6-7)
  - Note any authorized training sessions
  - Track which quarters were active
  
QUARTERLY_REVIEW:
  - At end of each quarter, calculate total sessions
  - Identify if quarter is active (≥21 sessions)
  - Determine predominant MMM level
  - Plan ahead for reference period requirements
```

---

## 10. WIP RURAL ADVANCED SKILLS (RAS) - SEPARATE PROGRAM

**Note:** This is a SEPARATE payment stream, not part of FPS but available to same doctors.

### 10.1 Basic Requirements
```
ADDITIONAL_PAYMENT_AVAILABLE:
  - Must also provide primary care in MMM 3-7
  - Must meet minimum service thresholds
  - TWO separate streams (apply separately):
    
    STREAM_1_EMERGENCY:
      payment_range: $4,000 - $10,500 per annum
      requirements:
        - Emergency medicine services in hospital/urgent care clinic/multipurpose service
        - OR emergency after-hours in towns without hospital within 50km
        - Minimum roster/on-call requirements
    
    STREAM_2_ADVANCED_SKILLS:
      payment_range: $4,000 - $10,500 per annum
      requirements:
        - Recognized qualifications in: obstetrics, anaesthetics, surgery, 
          mental health, First Nations health, paediatrics, palliative care, 
          internal medicine
        - Minimum service levels using these skills
```

### 10.2 Application Period
```
APPLICATION_WINDOW: 2023-2026
MAXIMUM_APPLICATIONS: 4 (one per year for services in 2023, 2024, 2025, 2026)
SEPARATE_FROM: WIP Doctor Stream FPS (can receive both)
```

---

## 11. COMMON QUESTIONS & EDGE CASES

### 11.1 What if I change MMM locations mid-program?
```
ANSWER: 
  - Each quarter evaluated independently
  - Payment based on predominant MMM for active quarters
  - Year level continues (doesn't reset with location change)
  - May need to meet different reference period requirements for new MMM level
```

### 11.2 What if I take a break (e.g., parental leave, overseas)?
```
ANSWER:
  - Inactive quarters don't count against you
  - When you return, need 4 active quarters in most recent 8 quarters
  - Year level maintained (doesn't reset)
  - Previous active quarters still count if within reference period
```

### 11.3 Can I combine CPS and FPS?
```
ANSWER:
  - YES, if you do both MBS-billed and non-MBS services
  - CPS pays automatically for MBS component
  - Apply via FPS for "top-up" for non-MBS component
  - Must declare ALL eligible services in FPS application
```

### 11.4 What if I exceed 104 sessions in a quarter?
```
ANSWER:
  - Maximum 104 sessions counted per quarter
  - Excess sessions do NOT carry forward
  - Quarter still counts as active
  - Consider spreading sessions across quarters if possible
```

### 11.5 What if I work in non-eligible location?
```
ANSWER:
  - Only MMM 3-7 sessions count (except authorized training in MMM 1-2)
  - Sessions in MMM 1-2 (without authorization) are not counted
  - Track sessions by location to ensure minimum met in eligible locations
```

---

## 12. CHECKLIST FOR SUBSIDY TRACKING APP

### 12.1 Data to Collect from Doctor
```
PROFILE_DATA:
  ☐ Registration status (VR / Non-VR)
  ☐ If Non-VR: on approved training pathway? (Y/N)
  ☐ Training pathway name (if applicable)
  ☐ Payment history (previous WIP payments received)
  ☐ Start date in WIP program
  ☐ Primary state/territory of practice

SESSION_DATA_PER_ENTRY:
  ☐ Date of service
  ☐ Location (town name)
  ☐ MMM classification
  ☐ Start time
  ☐ End time (or duration in hours)
  ☐ Service type (primary care, training, procedural, etc.)
  ☐ MBS billed? (Y/N)
  ☐ If training: RTO authorization? (Y/N)
  ☐ If MM6-7: special activities? (travel, population health, etc.)
```

### 12.2 Calculations to Perform
```
QUARTERLY_CALCULATIONS:
  ☐ Total sessions per quarter
  ☐ Sessions by MMM level per quarter
  ☐ Predominant MMM level per quarter
  ☐ Quarter active status (≥21 sessions)
  ☐ Sessions exceeding maximum (if >104)

PROGRAM_CALCULATIONS:
  ☐ Number of active quarters in reference period
  ☐ Current year level
  ☐ Eligibility status (meets reference period requirements?)
  ☐ Payment amount calculation
  ☐ Next payment due date
  ☐ Quarters remaining to next payment
```

### 12.3 Warnings to Generate
```
ALERTS:
  ☐ Quarter approaching 104 session limit
  ☐ Quarter below 21 session minimum
  ☐ Working in non-eligible MMM location
  ☐ Session duration <3 hours
  ☐ >2 sessions claimed in single day
  ☐ Reference period expiring without minimum active quarters
  ☐ Bank details not provided within 60 days of notification
  ☐ FPS application due
  ☐ Missing RTO verification for training sessions
```

### 12.4 Reports to Generate
```
RECOMMENDED_OUTPUTS:
  ☐ Current eligibility status dashboard
  ☐ Payment forecast (next payment amount & timing)
  ☐ Quarterly session summary
  ☐ Active quarter tracker (visual calendar)
  ☐ FPS application pre-fill (ready for submission)
  ☐ Year-over-year comparison
  ☐ MMM location distribution
  ☐ Documentation checklist for FPS submission
```

---

## 13. QUICK REFERENCE FORMULAS

```
ACTIVE_QUARTER = (sessions >= 21) AND (each_session >= 3_hrs) AND (mmm IN [3,4,5,6,7])

PAYMENT_ELIGIBLE_NEW_MM357 = (active_quarters >= 8) in last_16_quarters
PAYMENT_ELIGIBLE_NEW_MM67 = (active_quarters >= 4) in last_8_quarters
PAYMENT_ELIGIBLE_CONTINUING = (active_quarters >= 4) in last_8_quarters

YEAR_LEVEL = min(4, payments_received + initial_year_level)

PAYMENT_AMOUNT_VR = payment_matrix[year_level][mmm_mode]
PAYMENT_AMOUNT_NON_VR = PAYMENT_AMOUNT_VR * 0.8

SESSIONS_COUNTED_PER_QUARTER = min(104, valid_sessions)
SESSIONS_PER_DAY = max(2, claimed_sessions_per_day)
```

---

## APPENDIX A: ELIGIBLE PRIMARY CARE SERVICES (MBS ITEM EXAMPLES)

```
ELIGIBLE_MBS_CATEGORIES:
  - Category 1: Professional attendances (GP consultations)
  - Category 2: Diagnostic procedures and investigations
  - Category 3: Therapeutic procedures
  - Category 4: Oral and maxillofacial services (specific items)
  - Category 5: Diagnostic imaging services (specific items)
  - Category 6: Pathology services (specific items)
  - Category 7: Cleft lip and cleft palate services
  - Telehealth items within above categories

NOTE: See WIP Guidelines for complete MBS item list
```

---

## APPENDIX B: RURAL WORKFORCE AGENCY CONTACT DETAILS

```
NSW: Rural Doctors Network
  Email: [Contact via FPS application]
  
VIC: Rural Workforce Agency Victoria (RWAV)
  Email: wip@rwav.com.au
  Phone: 03 9349 7800

QLD: Health Workforce Queensland
  Email: [Contact via FPS application]

SA: Rural Doctors Workforce Agency (RDWA)
  Email: WIP@ruraldoc.com.au
  Phone: 1800 010 550

WA: Rural Health West
  Email: [Contact via FPS application]
  Phone: 08 6389 4500

TAS: Rural Health Tasmania
  Email: [Contact via FPS application]

NT: Northern Territory Primary Health Network
  Email: [Contact via FPS application]

ACT: Serviced via NSW Rural Doctors Network
```

---

## DOCUMENT VERSION CONTROL

```
VERSION: 1.0
LAST_UPDATED: 2024-01-18
BASED_ON: WIP Doctor Stream Guidelines (effective from 1 January 2020, updated January 2024)
SOURCE: Australian Government Department of Health and Aged Care
NEXT_REVIEW: Quarterly or when program guidelines updated
```

---

## IMPORTANT DISCLAIMERS

1. **Verify Current Rules:** Always check https://www.health.gov.au/our-work/workforce-incentive-program/doctor-stream for most current program guidelines
2. **Individual Circumstances:** This document provides general guidance. Individual eligibility may vary.
3. **Not Legal/Financial Advice:** This is an informational guide for tracking purposes only
4. **RWA Authority:** Rural Workforce Agencies make final determinations on FPS applications
5. **Payment Calculation:** Services Australia processes actual payments; amounts may vary based on individual circumstances
6. **Program Changes:** WIP Doctor Stream rules may change; check for updates regularly

---

**END OF DOCUMENT**
