# App Store Reviewer Notes
## Keisan - Airline Crew Salary Calculator

**App Name:** Keisan  
**Version:** 0.2.0+2  
**Language:** Turkish (Primary Interface)  
**Target Audience:** Airline crew members  
**Developer Contact:** mankurt.keisan@gmail.com  

---

## 📋 Overview for Reviewers

Keisan is a specialized salary calculation application designed for airline crew members. The app analyzes PDF roster files to calculate salaries, track commissions, and manage financial records. This document provides essential information to help Apple reviewers test the app effectively.

---

## 🔐 Authentication & Initial Setup

### **First Launch - Legal Disclaimer**
- App displays a mandatory legal disclaimer (in Turkish)
- User must check the "I agree" checkbox and tap "Accept and Continue"
- This disclaimer appears only once per device installation

### **Google Authentication Required**
- **IMPORTANT:** App requires Google Sign-In for all functionality
- Use any valid Google account for testing
- No special test credentials needed
- Authentication is handled through Firebase Auth

### **Device Registration System**
- **Security Feature:** Each Google account can only be used on ONE device at a time
- If testing on multiple devices, use different Google accounts OR
- Use "Device Management" in Profile section to unregister from previous device
- This is an intentional security feature, not a bug

---

## 🧪 Testing Prerequisites

### **Required for Full Testing:**
1. **Google Account** - Any valid Google account
2. **PDF Files** - The app is designed to analyze airline roster PDF files
   - For testing purposes, any PDF file can be uploaded
   - Core functionality requires PDF upload to demonstrate roster analysis
   - Sample PDFs or any document PDFs will work for review purposes

### **Optional Test Data:**
- Commission amounts (can enter any numeric values)
- Currency rates (EUR/TRY conversion)
- Date ranges for historical calculations

---

## 🚀 Step-by-Step Testing Guide

### **Phase 1: Initial Setup**
1. Launch app
2. Accept legal disclaimer
3. Sign in with Google account
4. Device will be automatically registered
5. It will require approval of the admin!!

### **Phase 2: Core Functionality Testing**

#### **A. PDF Upload & Analysis**
1. Tap "Roster Yükle" (Upload Roster) on main screen
2. Select any PDF file from device
3. Wait for analysis completion
4. Tap "Analizi Tamamla" (Complete Analysis)
5. Review the generated roster summary
6. Optional: Save results using "Kaydet" (Save) button

#### **B. Salary Calculations**
1. Navigate to "Hesapla" (Calculate) section
2. Set base salary using top button
3. Adjust EUR exchange rate if needed
4. Enter any commission amounts for testing
5. Select calculation period
6. Tap calculate to see salary breakdown

#### **C. Commission Management**
1. Go to "Komisyonlar" (Commissions) section
2. Add test commissions using calendar interface
3. Enter any amount and select crew size (5-person checkbox)
4. View commission history and period summaries

#### **D. Historical Records**
1. **Roster History:** View saved PDF analysis results
2. **Commission History:** View entered commission records
3. **Salary History:** View calculated salary summaries

### **Phase 3: Settings & Profile**
1. Access Profile section
2. Test "Device Management" feature
3. Review help documentation ("Kullanım Klavuzu")
4. Test contact support dialog

---

## 🎯 Key Features to Validate

### **✅ Core Functionality**
- [ ] Google authentication works smoothly
- [ ] PDF file upload and processing
- [ ] Mathematical calculations are displayed
- [ ] Data persistence across app sessions
- [ ] Navigation between all sections

### **✅ Security Features**
- [ ] Device registration system functions
- [ ] Single device per account enforcement
- [ ] Proper logout/unregistration

### **✅ User Experience**
- [ ] Turkish interface displays correctly
- [ ] App handles portrait/landscape orientations
- [ ] Loading states and error handling
- [ ] Help documentation accessibility

---

## ⚠️ Important Notes for Reviewers

### **Language Considerations**
- **Primary Language:** Turkish
- **Key Turkish Terms:**
  - "Roster Yükle" = Upload Roster
  - "Hesapla" = Calculate
  - "Komisyonlar" = Commissions
  - "Geçmiş" = History
  - "Profil" = Profile

### **Expected Behavior**
- **PDF Processing:** App analyzes any PDF but is optimized for airline roster formats
- **Calculations:** Results are estimates based on input data
- **Internet Required:** Authentication and data sync require internet connection
- **Device Limitation:** One account per device is intentional security feature

### **Known Limitations (Not Bugs)**
- App is specialized for Turkish airline industry terminology
- Some calculation features require specific roster data formats
- Partial day calculations are still in development (mentioned in help)
- 6th day flights require manual entry (documented feature)

---

## 🆘 Support & Contact

### **Technical Issues During Review**
- **Developer Email:** mankurt.keisan@gmail.com
- **Support Website:** https://mankurt01.github.io/keisan-support
- **Response Time:** Developer typically responds within 24 hours

### **Common Questions Addressed**
1. **"Why does authentication fail?"** - Ensure internet connection and valid Google account
2. **"Why can't I use same account on different device?"** - Security feature, use device management to switch
3. **"App seems complex?"** - Specialized tool for airline professionals, complexity is intentional
4. **"Calculations seem wrong?"** - App provides estimates; actual values depend on specific airline policies

---

## 📱 Testing Scenarios

### **Scenario 1: New User Experience**
1. Fresh install → Disclaimer → Authentication → PDF Upload → Basic calculation
2. **Expected Result:** Smooth onboarding with clear guidance

### **Scenario 2: Data Persistence**
1. Enter data → Close app → Reopen → Verify data is saved
2. **Expected Result:** All entered data persists correctly

### **Scenario 3: Device Management**
1. Sign in → Go to Profile → Device Management → Test unregistration
2. **Expected Result:** Proper logout and device unregistration

### **Scenario 4: Error Handling**
1. Try features without internet → Test with invalid files
2. **Expected Result:** Graceful error messages and recovery

---

## 🏷️ App Store Categories & Compliance

### **Category:** Business/Finance
- App helps professionals calculate work-related earnings
- Legitimate business use case for airline industry
- No gambling, inappropriate content, or policy violations

### **Age Rating:** 4+ (No restricted content)

### **Privacy:** 
- Uses Google Sign-In (standard OAuth)
- Stores user data in Firebase (Google's service)
- No sensitive personal data beyond work calculations
- Contact email available for privacy inquiries

---

## ✅ Pre-Review Checklist Completed

- [x] Encryption compliance documented (separate document)
- [x] Info.plist configured with encryption exemption
- [x] Firebase configuration properly set up
- [x] Google Sign-In properly configured
- [x] All required app icons and metadata included
- [x] Legal disclaimer implemented
- [x] Support contact information provided
- [x] App follows iOS design guidelines

---

**Final Note for Reviewers:** This app serves a legitimate niche market (airline crew salary calculations) and provides real value to its target users. While specialized, all functionality is accessible and testable with the guidance provided above. Thank you for your thorough review!
