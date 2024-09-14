# Apple Ads Attribution Demo Overview

## Overview
This document provides an overview of the demo code for Apple Ads Attribution, implemented in two versions: **Objective-C** (in the folder `Example-Objc`) and **Swift** (in the folder `Example-Swift`). It is important to note that while the IDFA (Identifier for Advertisers) can be retrieved if the user consents to tracking via ATT, Apple Ads Attribution is independent of IDFA access. Additionally, attribution tokens cannot be retrieved on the iOS simulator, so this demo must be run on a physical device.

### Pre-Permission Dialog (ATT Pre-Prompt)
The **ATT prompt** can only be shown once per app installation. To ensure users have another opportunity to reconsider their decision after denying permission for tracking, a **pre-permission dialog** is implemented in this demo. This custom pre-prompt allows the app to give the user more context before the system-level ATT prompt.

- **If the user selects "Agree" in the pre-prompt**, the app will proceed to show the official ATT prompt.
- **If the user selects "Disagree" in the pre-prompt**, the ATT prompt will not be shown again.

This approach ensures that users are better informed before making a decision and gives them a second chance to consent to tracking.

## What the Demo Does

### 1. ATT Permission Check
The demo includes a custom consent dialog (pre-prompt), and if necessary, triggers the system-level ATT prompt. Whether the user allows or denies ATT, attribution can still be performed. If the user allows ATT, more detailed data (like `clickDate`) will be available in the attribution response.

### 2. Retrieving the IDFA (Optional)
If the user agrees to ATT, the app can retrieve the IDFA using `ASIdentifierManager`. However, IDFA is **not required** for Apple Ads Attribution. Even if the user denies ATT and IDFA is not available, the app can still retrieve attribution data using the `AdServices` framework.

### 3. Retrieving Attribution Data
Once the attribution token is retrieved from `AdServices`, it is sent to Apple's server to fetch the attribution data. If ATT is allowed, the attribution data will include an extra field, `clickDate`, which provides the date and time the user interacted with the ad. If ATT is denied, the data will not include this field, but attribution can still be performed.

## Limitations of the Demo
- **Real Device Requirement**: The attribution token cannot be retrieved on the iOS simulator, as Apple Ads Attribution requires a real device to function properly.
- **Simplified Error Handling**: The demo code does not include comprehensive error handling. In production, additional mechanisms should be in place to handle potential issues such as network failures, API response errors, or invalid data.
- **Basic Retry Mechanism**: The demo implements a minimal retry mechanism for network requests. In a full production environment, more sophisticated retry strategies should be considered, including handling of transient errors and exponential backoff.
- **No Event Deduplication**: The demo does not account for event deduplication. In a production setting, it is important to ensure that duplicate attribution events are avoided to prevent over-reporting.

## Notes
- **Objective-C and Swift Versions**: The codebase is available in both Objective-C (`Example-Objc`) and Swift (`Example-Swift`) for your reference.
