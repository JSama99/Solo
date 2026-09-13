#!/usr/bin/env python3
import json
import statistics
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
DOC=ROOT/"Documentation/Atlantis"

def rows(name): return ET.parse(DOC/f"Phase12-iPhone16Pro-{name}.xml").getroot().findall(".//row")
def values(items,tag):
    return [int(node.text) for row in items if (node:=row.find(tag)) is not None and node.text and node.text.isdigit()]
def percentile(data,p):
    if not data:return 0
    data=sorted(data);return data[min(len(data)-1,int(len(data)*p))]

present=rows("ca-client-present-request")
times=values(present,"start-time")
intervals=[b-a for a,b in zip(times,times[1:]) if b>a]
display=values(rows("displayed-surfaces"),"duration")
driver_rows=[row for row in rows("metal-driver") if "SOLO: Unicorn Run" in ET.tostring(row,encoding="unicode")]
driver=values(driver_rows,"duration")
samples=rows("time-sample")
states={}
for row in samples:
    node=row.find("thread-state");state=node.get("fmt","Unknown") if node is not None else "Unknown";states[state]=states.get(state,0)+1
summary={
    "source":"Documentation/Atlantis/Phase12-iPhone16Pro-Metal.trace",
    "captureSeconds":10,
    "device":"iPhone 16 Pro (iPhone17,1), A18 Pro, iOS 26.7",
    "presentRequests":len(times),
    "presentRatePerSecond":len(times)/((times[-1]-times[0])/1e9),
    "presentIntervalP95MS":percentile(intervals,.95)/1e6,
    "presentIntervalMaximumMS":max(intervals)/1e6,
    "displayedSurfaceP95MS":percentile(display,.95)/1e6,
    "targetMetalDriverIntervals":len(driver),
    "targetMetalDriverTotalMS":sum(driver)/1e6,
    "targetMetalDriverP95MS":percentile(driver,.95)/1e6,
    "targetMetalDriverMaximumMS":max(driver,default=0)/1e6,
    "cpuTimeSamples":len(samples),
    "cpuThreadStates":states,
    "limitations":"A bounded post-stream steady-state capture. It is authoritative physical Metal/CPU timing evidence, but does not expose a GPU-utilization percentage or thermal sensor value through xctrace export."
}
(DOC/"Phase12-iPhone16Pro-Metal-summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
