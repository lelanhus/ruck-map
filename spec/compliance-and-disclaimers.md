# RuckMap Compliance & Disclaimers

## App Store Compliance

### Health & Fitness Positioning
- Position as "Fitness Tracker" not medical device
- All calorie calculations are "estimates for fitness tracking"
- Include standard fitness app disclaimers

### Required Disclaimers
1. **Fitness Disclaimer**: "Consult your physician before beginning any fitness program"
2. **Accuracy Disclaimer**: "Calorie calculations are estimates only and should not be used for medical purposes"
3. **GPS Disclaimer**: "Continued use of GPS running in the background can dramatically decrease battery life"

## Data Privacy

### Simple Privacy Model
- All data stored locally by default
- CloudKit sync is optional and user-controlled
- Location data never shared without explicit consent
- Start/end location fuzzing available as privacy option

### Unit Management Privacy
- Users explicitly join units
- Can leave units at any time
- Individual stats only visible if privacy settings allow
- Unit leaders see aggregate data only
- No automatic data sharing

## Security Requirements

### Consumer App Security
- Standard iOS security practices
- No special military compliance needed
- Use iOS Keychain for sensitive data
- CloudKit handles encryption in transit/at rest

### Unit Management Access
- Simple role-based access:
  - Member: View own data, unit aggregate
  - Leader: View unit aggregate, create challenges
  - Admin: Manage unit settings, remove members
- No complex military hierarchy needed

## Marketing Guidelines

### Acceptable Claims
- "Track your ruck training with precision"
- "Designed for serious ruckers"
- "Advanced calorie estimation"
- "Popular with military fitness enthusiasts"

### Avoid These Claims
- "Medical-grade accuracy"
- "DoD approved"
- "Diagnostic tool"
- "Prevents injuries"

## Implementation Notes

### MVP Simplifications
- No lab validation required
- Use published research for algorithm basis
- Gather user feedback for improvements
- A/B test algorithm variations

### Future Considerations
- If pursuing military contracts, revisit compliance
- If making medical claims, consider FDA guidelines
- If handling sensitive data, implement additional security

This approach keeps things simple while meeting App Store requirements and user expectations.