{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 # TripFlow iOS - Project Context\
\
## Overview\
\
TripFlow is an iOS travel planning application focused on organizing trips, locations and travel documents in one place.\
\
Users can:\
\
- create trips\
- add stops and locations\
- organize trips in a timeline\
- visualize locations on a map\
- scan and import travel documents\
- extract information using OCR\
\
The MVP is local-first and offline-friendly.\
\
---\
\
## Tech Stack\
\
- Swift\
- SwiftUI\
- SwiftData\
- MVVM\
- MapKit\
- Vision\
- VisionKit\
- XCTest\
\
---\
\
## MVP Scope\
\
Included:\
\
- Trip CRUD\
- Stop CRUD\
- Timeline\
- MapKit integration\
- Document scan/import\
- OCR extraction\
- Local persistence\
- Parser tests\
- Timeline tests\
\
Excluded:\
\
- Authentication\
- Cloud Sync\
- Firebase\
- User Accounts\
- Shared Trips\
- Booking Features\
- Social Features\
- Weather API\
- Budget Tracking\
- Route Optimization\
\
---\
\
## Architecture Rules\
\
- Keep architecture simple.\
- Prefer readability over abstraction.\
- Avoid overengineering.\
- Use small focused services.\
- Keep ViewModels lightweight.\
- Business logic belongs in Services.\
- SwiftData models should remain simple.\
\
---\
\
## Folder Structure\
\
- Models\
- Views\
- ViewModels\
- Services\
- Components\
- Helpers\
- Extensions\
- Resources\
\
---\
\
## Roadmap\
\
Phase 1:\
- Trip Management\
\
Phase 2:\
- Stops and Timeline\
\
Phase 3:\
- MapKit\
\
Phase 4:\
- OCR and Documents\
\
Phase 5:\
- Testing and Polish\
\
Future:\
- Widgets\
- App Intents\
- Smart Parsing}