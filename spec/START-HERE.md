# RuckMap Implementation Guide - START HERE

## Implementation Approach

This project will be built entirely by Claude Code through focused coding sessions. The implementation is organized into 25 discrete sessions that can be completed in 10-15 days of active development.

## Quick Start

### Week 1-2: Foundation
Build core tracking engine with GPS, distance, and pace calculations.
📄 Follow: `week-by-week-tasks.md` Days 1-10

### Week 3: Algorithm  
Implement LCDA calorie calculation with terrain detection.
📄 Reference: `rucking-calorie-algorithm-spec.md`
💻 Code: `technical-implementation-guide.md` Section 3

### Week 4-5: UI
Create the main tracking interface and map view.
📄 Stories: `mvp-user-stories.md` Epic 1

### Week 6: Watch & HealthKit
Build Watch app and integrate with HealthKit.
💻 Code: `technical-implementation-guide.md` Sections 5-6

### Week 7-8: Analytics & Polish
Add analytics dashboard and polish the experience.
📄 Checklist: `implementation-checklist.md` Phase 7-9

### Week 9-10: Testing & Release
Beta test and prepare for App Store.
📄 Follow: `implementation-checklist.md` Phase 10

## Document Guide

### Planning Docs
- `feature-list-v2.md` - Complete feature specifications
- `feature-roadmap.md` - Visual dependencies and timeline
- `mvp-user-stories.md` - User stories with acceptance criteria

### Implementation Docs (For Claude Code)
- `claude-code-implementation-plan.md` - 25 focused sessions with clear goals
- `claude-code-session-templates.md` - Copy-paste templates for each session
- `technical-implementation-guide.md` - Code snippets and patterns
- `implementation-checklist.md` - Complete task checklist

### Reference Docs
- `rucking-calorie-algorithm-spec.md` - Algorithm details
- `compliance-and-disclaimers.md` - Legal and App Store requirements

## Critical Success Factors

### 1. GPS Efficiency
Must achieve <10% battery drain per hour.
See: `technical-implementation-guide.md` Battery Optimization

### 2. Calorie Accuracy  
Target <10% error vs research data.
See: `rucking-calorie-algorithm-spec.md`

### 3. User Experience
60fps UI with intuitive controls.
See: `mvp-user-stories.md` Acceptance Criteria

## Claude Code Session Workflow

### Starting a Session
1. Pick next session from `claude-code-implementation-plan.md`
2. Copy the template from `claude-code-session-templates.md`
3. Include all specified context files with @ mentions
4. Run the session with clear success criteria

### During a Session
1. Let Claude Code implement the full component
2. Test functionality before moving on
3. Verify performance metrics are met
4. Ensure all tests pass

### After a Session
1. Review the implementation
2. Check off completed items in `implementation-checklist.md`
3. Document any decisions or limitations
4. Plan the next session

## Red Flags

⚠️ **Stop and fix if:**
- Battery drain >15%/hour
- Memory growing unbounded  
- Calorie calculations off by >20%
- Crashes in background mode

## Getting Help

### Technical Questions
Reference `technical-implementation-guide.md` for patterns

### Feature Questions
Check `mvp-user-stories.md` for requirements

### Priority Questions
Follow `feature-roadmap.md` dependencies

## Getting Started with Claude Code

### First Session
1. Start with Session 1 from `claude-code-implementation-plan.md`
2. Use this prompt template:
```
@spec/claude-code-session-templates.md 
Use the "Session 1: Project Setup" template to create the RuckMap project.
Include all specified requirements and verify the setup is complete.
```

### Best Practices
- **One session = One complete component** (2-4 hours of Claude Code time)
- **Always include context files** with @ mentions
- **Test during the session** not after
- **Be specific** about performance requirements
- **Document decisions** in code comments

### Session Scheduling
- Run 2-3 sessions per day maximum
- Allow time between sessions to review
- Complete each phase before moving to next
- Test thoroughly before starting new features

Remember: Focus on shipping a stable MVP. The plan is designed for Claude Code's strengths - clear tasks with defined outcomes.

Good luck! You're building something that will help thousands of ruckers train smarter. 🎒