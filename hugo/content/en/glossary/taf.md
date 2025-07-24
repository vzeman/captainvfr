+++
title = 'TAF'
date = 2025-07-24T12:00:00Z
draft = false
url = ""
description = "TAF (Terminal Aerodrome Forecast) - detailed weather forecast for airports covering a 24-30 hour period"
keywords = ["TAF", "Terminal Aerodrome Forecast", "weather forecast", "aviation weather", "flight planning"]
image = ""
term = "TAF"
shortDescription = "Terminal Aerodrome Forecast - detailed airport weather forecast"
category = "T"
tags = ["weather", "forecast", "meteorology", "flight planning"]
faq = [
  {
    question = "What is TAF?",
    answer = "TAF stands for Terminal Aerodrome Forecast, a detailed weather forecast specifically for airports. TAFs predict weather conditions including wind, visibility, weather phenomena, and cloud coverage for periods typically ranging from 24 to 30 hours."
  },
  {
    question = "How does TAF work?",
    answer = "TAFs are issued by meteorologists who analyze weather patterns, models, and current conditions to predict future weather at specific airports. They use standardized coding similar to METARs and are updated regularly, typically every 6 hours or when significant changes are expected."
  }
]
additionalImages = []

# CTA Section Configuration (optional)
showCTA = true
ctaHeading = "Plan with Confidence Using CaptainVFR"
ctaDescription = "Access comprehensive TAF forecasts and weather trends to make informed flight planning decisions."
ctaPrimaryText = "Weather Services"
ctaPrimaryURL = "/features/weather-services/"
ctaSecondaryText = "Get Started"
ctaSecondaryURL = "/download/"
+++

## Understanding Terminal Aerodrome Forecasts

Terminal Aerodrome Forecasts (TAFs) are essential tools for flight planning, providing detailed weather predictions for specific airports. Unlike METARs which report current conditions, TAFs look ahead, helping pilots anticipate weather changes and make informed decisions about departure times, routing, and fuel requirements.

## TAF Format and Structure

### Basic Components

A TAF contains:
- Forecast type and location
- Issue time and validity period
- Base forecast conditions
- Expected changes
- Temporary variations
- Probability groups

### Example TAF
```
TAF KJFK 121730Z 1218/1324 24015G25KT P6SM BKN025
  FM122100 25012KT P6SM SCT035
  FM130200 27008KT P6SM FEW050
  FM131000 VRB03KT 4SM BR SKC
  TEMPO 1312/1316 2SM BR
```

## Decoding TAF Elements

### Header Information

**Type and Amendment Indicators**
- **TAF**: Routine forecast
- **TAF AMD**: Amended forecast
- **TAF COR**: Corrected forecast

**Issue Time**
- Format: DDHHmmZ
- Indicates when forecast was prepared

### Validity Period

**Format**: DDhh/DDhh
- First group: Start day and hour
- Second group: End day and hour
- Times in UTC (Zulu)

Example: 1218/1324 = Valid from 12th at 1800Z to 13th at 2400Z

### Forecast Elements

**Wind**
- Same format as METAR
- May include gusts
- VRB for variable direction

**Visibility**
- P6SM: Plus 6 statute miles (US)
- 9999: 10 km or more (International)
- May include directional minimums

**Weather Phenomena**
- Same codes as METAR
- Intensity, descriptor, precipitation, obscuration

**Sky Condition**
- Cloud coverage and heights
- Same terminology as METAR
- CB (Cumulonimbus) when applicable

## Change Groups

### FM (From)
- Indicates permanent change
- Specific time of change
- All elements change
```
FM122100 25012KT P6SM SCT035
```
From 21:00Z on the 12th: Wind 250° at 12 knots, visibility greater than 6 miles, scattered clouds at 3,500 feet

### BECMG (Becoming)
- Gradual change over period
- Usually 1-2 hours
- Not all elements must change
```
BECMG 1314/1316 BKN012
```
Becoming broken at 1,200 feet between 14:00Z and 16:00Z on the 13th

### TEMPO (Temporary)
- Temporary fluctuations
- Less than half the period
- Conditions expected to revert
```
TEMPO 1312/1316 2SM BR
```
Temporarily 2 miles visibility in mist between 12:00Z and 16:00Z on the 13th

### PROB (Probability)
- PROB30: 30% probability
- PROB40: 40% probability
- Cannot use PROB50 or higher
- Time period follows
```
PROB30 1318/1322 1SM +TSRA
```
30% probability of 1 mile visibility in heavy thunderstorm and rain between 18:00Z and 22:00Z on the 13th

## Special Considerations

### NSW (No Significant Weather)
- Indicates end of precipitation
- Clear improvement expected

### CAVOK
- Ceiling And Visibility OK
- Visibility 10km or more
- No cloud below 5,000 feet
- No significant weather

### Wind Shear
- WS followed by runway
- Height and wind change
```
WS010/31025KT
```
Wind shear on runway 10, 310° at 25 knots at surface

## TAF Types by Duration

### Short TAF (12 hours)
- Smaller airports
- Less complex operations
- Updated more frequently

### Regular TAF (24 hours)
- Most common type
- Standard airports
- 6-hour update cycle

### Long TAF (30 hours)
- Major airports
- International operations
- Extended planning capability

## Using TAFs for Flight Planning

### Pre-flight Analysis

1. **Check validity period**: Ensure TAF covers your flight time
2. **Identify trends**: Look for improving or deteriorating conditions
3. **Note change times**: Plan around weather transitions
4. **Consider alternates**: If marginal conditions expected
5. **Fuel planning**: Account for potential holding or diversions

### Critical Elements for VFR

- Ceiling heights vs terrain
- Visibility trends
- Wind changes affecting runway selection
- Temporary reductions below minimums
- Improvement timing for departure

### IFR Considerations

- Approach minimums at ETA
- Alternate requirements
- Icing conditions
- Convective activity
- Wind shear potential

## Common TAF Scenarios

### Frontal Passage
```
TAF KORD 151430Z 1515/1618 18012KT P6SM BKN250
  FM151800 20015G25KT P6SM SCT050 BKN150
  FM160000 23020G35KT 3SM -SHRA BKN025 OVC050
  FM160300 29015KT P6SM SCT035
```
Shows approach and passage of cold front

### Morning Fog
```
TAF KSFO 150530Z 1506/1612 VRB03KT 1/2SM FG VV002
  FM151400 27010KT P6SM SKC
  FM160400 00000KT 2SM BR SKC
  TEMPO 1606/1610 1/2SM FG VV001
```
Typical radiation fog pattern with afternoon clearing

### Building Thunderstorms
```
TAF KDEN 151130Z 1512/1618 09008KT P6SM SKC
  FM151800 15012KT P6SM SCT040 BKN100
  PROB40 1520/1524 VRB25G45KT 1SM +TSRA BKN015CB
  FM160200 35010KT P6SM SCT050
```
Afternoon convective development

## TAF Amendments

### When Issued
- Significant changes from original
- Conditions deteriorating below minimums
- Improvement occurring earlier
- Wind shift timing changes

### AMD Indicators
- Supersedes previous TAF
- Valid for remainder of original period
- Check issue time carefully

## International Differences

### Format Variations
- Visibility: Meters vs statute miles
- Temperature forecasts in some countries
- QNH trends included
- Additional national codes

### Terminology
- CAVOK usage more common internationally
- Different probability thresholds
- Regional weather phenomena codes

## Digital TAF Access

Modern sources include:
- Aviation weather websites
- Flight planning applications
- Mobile apps like CaptainVFR
- Briefing services
- Data link in flight

## Limitations and Considerations

### Forecast Accuracy
- Decreases with time
- Best within first 12 hours
- Weather changes can occur rapidly
- Always have contingency plans

### Update Frequency
- Check latest amendments
- Monitor for unscheduled updates
- Compare with current METARs
- Verify trends are occurring

### Geographic Limitations
- TAF only for immediate airport area
- Typically 5-mile radius
- En route weather requires other products
- Consider neighboring TAFs

TAFs are indispensable for flight planning, providing crucial forecast information that helps pilots make safe, informed decisions. Combined with METARs and other weather products, TAFs form a comprehensive picture of expected conditions, enabling pilots to plan flights that avoid hazardous weather while maximizing efficiency and safety.