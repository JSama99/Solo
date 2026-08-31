# Build 32.7.7 performance observation

- Build: 32.7.7 (32707), Debug simulator build.
- Device/runtime: iPad Air 11-inch (M4), iOS 26.5 Simulator.
- Flow: deterministic Physical Garage idle fixture, no gameplay action.
- First sample: PID 25300, elapsed 11 seconds, resident memory 348,112 KB, host-reported CPU 21.5%.
- Second sample: same PID, elapsed 42 seconds after an additional 20-second idle hold, resident memory 348,016 KB, host-reported CPU 21.5%.
- Observation: memory did not grow during the hold (−96 KB between samples). The production continuity UI run also held the Garage idle for 16 seconds and completed its 101.875-second device/camera flow without crash or assertion failure.
- Caveat: these are Debug simulator process observations. They are not release-device frame-time, energy, or peak-memory claims. A symbolicated ETTrace capture was not possible because the ETTrace runner/framework was unavailable; no hotspot attribution is claimed.
