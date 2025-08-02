# RuckMap (temporary name)

## Description:
iOS fitness application catering the growing rucking community. App features ruck logging, GPS route tracking, scientifically backed calorie and work algorithms, analytics, and more. The app includes integration with HealthKit and has a companion iOS application. 

## Technology:
- Swift 6
- SwiftUI, including new Liquid Glass that will be released in about two months
- SwiftCharts
- SwiftTesting (SwiftTesting and XCTest for views if needed)
- SwiftData
- Apple HealthKit integrations
- Any additional Applie APIs
- CloudKit
- Telemetry Deck
- WishKit
- RevenueCat
- 

## Key Features:
- Ruck logging
-- Route
-- Time
-- Pace
-- Elevation
-- Work
-- Calories (research/calorie-algorithm-research.md)
-- Weight
-- Weather
-- RPE
- Basic and advanced analytics/metrics
- HealthKit integration
- WeatherKit
- CloudKit
- WatchOS companion app on day 1
- We need a way to evaluate ruck quality
- a route planning, rating, and saving would be good
- saving photos or notes from points along the route would be good
- eventually we need a way to provide scoring for users that would be built around the ruck difficulty and user metrics. I was thinking some kind of federated ML system so we could have a universal metric
- recovery would be a good thing to look at in the app too.
- social sharing and possibly additiona community features like meet ups, message boards, messages, etc could be could. It would be good if you could make a ruck club or something too.
- I want to keep the backend either absent or extremely lightweight initially
- AI coach would be great and basically any AI-First features we can implement

## Architecture Considerations
- I think we can use MV pattern with macros in modern SwiftUI
- We should plan to have Liquid Glass working from Day 1, but need to plan for pre- Liquid Glass
- Let's assume at least iOS 18+
- We want to maintain accessibility
- We can use dynamic type
- Avoid a backend if possible. We don't want to be overly restrictive, but if we can keep it limited it would be nice. I'm open to using Firebase unless we require something different.

## UI/UX
- Use SwiftUI core colors but use mixing and other features to achieve the correct colors so that we can leverage the automatic light/dark optimization (swiftui-adaptive-colors.md)
- We should leverage microanimations and interactions to enrich the user experience (https://benji.org/honkish)
- Favor a sleek, fun, professional, refined monochromatic theme
- Theme changing would be a nice feature
- Use SF Symbols and default fonts with proper typography rules of thumb and white space to make the typography feel custom without having to use custom fonts (swiftui-fonts.md)