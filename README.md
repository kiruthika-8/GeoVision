# GeoVision

A Flutter based application built as a feature-driven improvement over existing Geotag applications, by adding the essential features to enhance the application like anti-spoofing GPS locks, server-side timestamps, offline persistence, tamper-proof, real-time dashboard that ensures secure, verified, and automated Industrial Visit reporting using geo-validation and cloud technologies.

## Features
* Camera access enabled only after selecting an approved IV session.
* Immutable GPS geotagging bound at capture time.
* Server-side verification using Firebase timestamps and location checks.
* Offline architecture for zero-network industrial areas.
* Automated report organization and one-click PDF generation.
* Role-based dashboards for faculty, HODs, and Deans.

## Tech Stack
* Frontend: Flutter (Android Studio)
* Backend: Firebase:
  - Fire-store database
  - Firebase authentication
  - Firebase cloud functions 
  - Firebase storage
* Location Services : GPS , Geofencing APIs
* Offline Storage : Fire-store persistence
* Security: firebase server timestamps and rules

## Architecture
<p><b>
Phase 1: Authentication & Role Routing<b><br>
<p align="center">
Login (Email & Password)<br>
↓<br>
Role Verification (Faculty / Admin)<br>
↓<br>
Smart Routing → Faculty Dashboard / Admin Dashboard
</p>

<p><b>Phase 2: Faculty Workflow</b></p>

<p align="center">
Select Industrial Visit Session<br>
<br>
Initialize Camera + GPS<br>
↓<br>
Capture Photo Evidence<br>
↓<br>
Add Rating & Feedback<br>
↓<br>
Submit (GPS Verified)
</p>

<p><b>Phase 3: Cloud Processing</b></p>

<p align="center">
Upload Image to Cloud Storage<br>
↓<br>
Create JSON (Location + Feedback)<br>
↓<br>
Server Timestamp Added
</p>

<p><b>Phase 4: Admin Workflow</b></p>

<p align="center">
Real-Time Dashboard (Live Feed)<br>
↓<br>
Instant Report Sync<br>
↓<br>
Filter by Department / Company<br>
↓<br>
Verify & Approve Visit
</p>

# Authors
Kiruthika C G , Visagan G
