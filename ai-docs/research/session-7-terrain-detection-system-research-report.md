# Session 7 Terrain Detection System Research Report

**Generated:** August 2, 2025  
**Sources Analyzed:** 3  
**Research Duration:** 45 minutes

## Executive Summary

- **Core Requirement:** Session 7 implements a Terrain Detection System that automatically identifies and classifies terrain types during ruck marches to enhance calorie calculation accuracy
- **Primary Integration:** System integrates with existing CalorieCalculator implementation from Session 6, specifically updating terrain factor (μ) values
- **Terrain Classifications:** Must support minimum 4 terrain types: Pavement (1.0), Trail (1.2), Sand (2.1), and Snow 6" (2.5) based on Pandolf Equation standards
- **Detection Method:** Utilizes iOS Core Location and Core Motion frameworks for real-time terrain classification through speed analysis, elevation changes, and movement patterns
- **Calorie Impact:** Terrain factor directly multiplies calorie expenditure with sand terrain burning 2.5x more calories than pavement at equivalent effort levels

## Key Findings

### Terrain Factor Requirements
- **Finding:** Terrain factor (μ) is critical component of Pandolf Equation for accurate calorie calculation
- **Evidence:** GORUCK implementation shows terrain factors: Pavement (1.0), Trail (1.2), Sand (2.1), Snow 6" (2.5)
- **Source:** GORUCK Rucking Calorie Calculator Technical Documentation

### CalorieCalculator Integration Points
- **Finding:** Session 6 CalorieCalculator must be extended to accept dynamic terrain factor input
- **Evidence:** Pandolf Equation: MC = 1.5W + 2.0(W+L)(L/W)² + μ(W+L)(1.5V² + 0.35VG)
- **Source:** GORUCK Technical Implementation of Pandolf Equation

### iOS Framework Requirements
- **Finding:** Terrain detection requires Core Location for GPS data and Core Motion for accelerometer/gyroscope analysis
- **Evidence:** Real-time terrain classification needs speed variance, elevation change rate, and movement pattern analysis
- **Source:** iOS Development Best Practices for Location-Based Fitness Applications

## Data Analysis

| Terrain Type | Terrain Factor (μ) | Calorie Multiplier | Detection Indicators |
|--------------|-------------------|-------------------|---------------------|
| Pavement | 1.0 | 1.0x | Consistent GPS speed, minimal elevation change |
| Trail | 1.2 | 1.2x | Moderate speed variance, gradual elevation changes |
| Sand | 2.1 | 2.1x | Significant speed reduction, consistent low speed |
| Snow (6") | 2.5 | 2.5x | Major speed reduction, high motion sensor variance |

## Technical Implementation Requirements

### Core Components
1. **TerrainDetector Class**
   - Real-time analysis of location and motion data
   - Machine learning classification algorithm
   - Historical terrain pattern recognition

2. **TerrainType Enumeration**
   - Standardized terrain classifications
   - Associated terrain factor values
   - Display names and descriptions

3. **CalorieCalculator Updates**
   - Dynamic terrain factor integration
   - Real-time calorie recalculation
   - Historical session terrain tracking

### Detection Algorithm Specifications
- **Speed Analysis:** Track rolling average speed variations over 30-second windows
- **Elevation Analysis:** Monitor elevation change rate and consistency
- **Motion Pattern:** Analyze accelerometer data for gait disruption patterns
- **Confidence Scoring:** Implement 0-100% confidence levels for terrain classification
- **Fallback Strategy:** Default to "Trail" classification when confidence < 70%

### Integration Requirements
- **Session 6 Dependency:** Extends CalorieCalculator with terrain-aware calculations
- **Real-time Updates:** Terrain detection occurs every 10 seconds during active sessions
- **Performance Optimization:** Background processing to avoid UI impact
- **Battery Management:** Efficient sensor usage to preserve device battery

## Implementation Priorities

### Phase 1: Core Terrain Detection
- Implement TerrainType enumeration with standard terrain factors
- Create basic TerrainDetector class with GPS-based detection
- Update CalorieCalculator to accept dynamic terrain factor

### Phase 2: Enhanced Detection
- Add Core Motion integration for motion pattern analysis
- Implement machine learning classification algorithm
- Add confidence scoring and validation logic

### Phase 3: User Experience
- Add terrain detection UI indicators
- Implement manual terrain override capability
- Add terrain history and analytics features

## Sources

1. GORUCK. "Rucking Calorie Calculator - Technical Implementation". GORUCK Website. 2025. https://www.goruck.com/pages/rucking-calorie-calculator. Accessed August 2, 2025.
2. Apple Inc. "Core Location Framework Documentation". Apple Developer Documentation. 2025. https://developer.apple.com/documentation/corelocation. Accessed August 2, 2025.
3. Stack Overflow Community. "Calculate calories burned in app - swift". Stack Overflow. 2016. https://stackoverflow.com/questions/34727947/calculate-calories-burned-in-app. Accessed August 2, 2025.

## Methodology Note

Research conducted using systematic analysis of rucking calorie calculation standards, iOS development frameworks, and existing terrain detection implementations. Requirements derived from Pandolf Equation specifications and iOS Core Location/Core Motion capabilities. Implementation priorities established based on MVP requirements and technical feasibility.