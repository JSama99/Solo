# Build 32.5.1 Input and Camera Remediation

Computer Focus has no root `DragGesture` and no parent monitor tap recognizer. The embedded `FounderComputerScreen` owns scrolling and canonical controls.

Free Look creates an explicit full-room drag surface only after the computer has `allowsHitTesting(false)`, plus a separate visible monitor-sized return button above that surface. The control rail remains above both. Drag start is captured locally, translation is normalized by available size, and each gesture adds to that start position. Camera state stays local to the view and never reaches `GameStore`, saves, or RNG.
