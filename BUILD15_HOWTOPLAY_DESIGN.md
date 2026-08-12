# Build 15 How to Play Design

## Reference model

How to Play is a static, always-available rules reference rather than a guided tutorial. Its collapsed disclosure groups form the table of contents, with entry points from the title screen and the More tab.

## Truth sources

Sprint rows are derived from `SprintPhase.allCases`; doctrine values are derived at rendering from `DoctrineProfile.profile(for:)`. This prevents the reference from silently diverging during future sequencing or balance changes.

## Build 14 dependency

Product Type is not present on this branch, so Setup Choices documents Career Length and Doctrine only. Add Product Type reference material when Build 14 lands.
