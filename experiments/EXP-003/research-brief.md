# EXP-003 Research Brief: Edge Demand-Launch Responsiveness

## Customer problem
Microsoft Edge should open and become interactive immediately when requested without placing an Edge shortcut in the Startup folder.

## Objective
Find the fastest supported Edge demand-launch configuration while measuring the resource cost of any prelaunch or background preparation.

## Constraints
- No Edge Startup-folder entry
- Preserve profiles, passwords, cookies, favorites, security controls, update behavior, and management policy
- Test one variable at a time
- Preserve exact original configuration and rollback

## Candidate variables
- Startup Boost
- Continue running background extensions and apps
- Sleeping Tabs
- Installed extensions
- Profile and first-run state
- Hardware acceleration
- Cache and profile storage behavior
- Documented Edge enterprise policies

## Benchmark
Use repeated runs and medians for:
- Cold process launch to visible window
- First interactive window
- First new-tab readiness
- First navigation completion to a controlled local or fixed test page
- Idle memory and process cost before demand launch

Compare true cold launch with supported Startup Boost or background preparation. Record the resource tradeoff.

## Status
Experimental. No performance claim exists until repeated physical-machine results are recorded.
