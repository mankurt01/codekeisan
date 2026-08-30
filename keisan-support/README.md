# Keisan App Support

This repository contains the support page for the Keisan App - a salary calculation application for airline crew members.

## About Keisan App

Keisan is a mobile application designed to help airline crew members calculate their salaries by analyzing roster PDF files. The app provides features for:

- PDF roster analysis
- Commission tracking
- Salary history
- Base salary calculations
- Currency conversion (EUR/TRY)

### Layover Calculation Details

Layovers are detected by scanning the roster PDF for patterns like `H<number> <AIRPORT_CODE>` before section headers (e.g., "Hotels", "Crew Information"). Each valid match is counted as a layover. The total layover count is used in salary and statistics calculations. Only lines before the schedule section ends are considered for layover detection.

## Support

For technical support, questions, or feedback about the Keisan App, please contact:

**Email:** mankurt.keisan@gmail.com

## Website

The support page is available at: [https://mankurt01.github.io/keisan-support](https://mankurt01.github.io/keisan-support)

## Files

- `index.html` - Main support page with contact information, FAQ, and app details
- `README.md` - This file

## Setup Instructions

To set up GitHub Pages for this repository:

1. Go to your repository Settings
2. Scroll down to "Pages" section
3. Under "Source", select "Deploy from a branch"
4. Choose "main" branch and "/ (root)" folder
5. Click "Save"

Your support page will be available at: `https://mankurt01.github.io/keisan-support`

## Version

Current app version: 1.0.0

## Legal Notice

This application is provided for informational purposes only. All calculations are estimates and should not be used for official financial planning or legal decisions.
