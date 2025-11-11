# Caliber Core

Caliber Core is the foundational framework of the **Caliber Platform**.  
It provides the shared data model, services, and configuration layer that power all Caliber modules—enabling consistent logic, security, error handling, and metadata-driven automation across the entire ecosystem.

## Overview

This package establishes the **platform backbone** for every Caliber solution, defining reusable Apex services, shared metadata, and dependency structures.  
It delivers standardized naming conventions, error logging, integration registries, and dynamic configuration utilities that other packages extend, ensuring that all Caliber modules operate as one cohesive system.

Caliber Core is the required base layer for all Caliber Platform modules, including Commerce, Project Management, Restoration, and MagicPlan Integration.

---

## Core Features

- **Error Logging Framework** – Centralized Apex error handling via `ErrorLogService`, compatible with Flows, Triggers, and Invocable Actions.  
- **Integration Registry** – Metadata-driven configuration for external APIs (e.g., Stripe, SignatureAPI, MagicPlan), supporting secure named credential mapping.  
- **Dynamic Numbering Engine** – Reusable numbering logic for documents such as Proposals, Contracts, and Invoices.  
- **Custom Metadata Utilities** – Extensible CMDT framework for declarative business rules and package configuration.  
- **JSON & Data Utility Classes** – Simplified object serialization, map conversion, and dynamic type utilities for Apex and Flow use.  
- **Shared Lookup Relationships** – Universal relationships such as Business Unit, Brand, and Account context across all modules.  
- **Trigger Framework** – Modular, order-safe trigger management system designed for large-scale package interoperability.  
- **Error Handling in Flows** – Invocable actions that route Flow errors to centralized logging automatically.  
- **Cross-Package Constants** – Shared global constants for field names, picklist values, and transaction types.  
- **Integration Registry Editor (Future)** – Planned LWC for editing integration metadata directly in-app.

---

## Package Dependencies

Caliber Core is the foundation layer and **must be installed first** before any other Caliber module.

Dependent modules include:
- **Caliber Commerce** – Financial lifecycle and billing engine.  
- **Caliber Project Management** – Project, phase, and operational tracking.  
- **Caliber Restoration** – Restoration industry specialization.  
- **Caliber MagicPlan Integration** – Field data synchronization and diagram integration.

---

## Installation & Setup

1. Install the package:  
   `Caliber Core`
2. Assign permission sets:
   - `Caliber Core Admin`
   - `Caliber Core User`
   - `Caliber Core Read Only`
3. Add **Caliber Core** Lightning App for direct access to Core utilities.  
4. Configure **Integration Registry** entries for external systems:
   - Stripe, SignatureAPI, MagicPlan, QuickBooks, etc.
5. Enable optional utilities:
   - ErrorLog Flows  
   - Dynamic Numbering Rules  
   - Global Configuration CMDT

---

## Data Model

Caliber Core introduces standardized, cross-package data relationships and configuration objects used by all Caliber modules.

### Foundational Objects
| Object | Description |
|---------|-------------|
| **Error_Log__c** | Records handled errors and exceptions from Apex and Flow for auditing and debugging. |
| **Integration_Registry__mdt** | Custom metadata type defining external service endpoints and credentials. |
| **Numbering_Rule__mdt** | Defines prefixes, sequence patterns, and reset logic for auto-numbered records. |
| **Global_Configuration__mdt** | Centralized settings for cross-package toggles and feature flags. |
| **Business_Unit__c** | Represents a brand, company, or division operating under the Caliber umbrella. |
| **Brand_Theme__c** | Stores logo, color, and styling metadata for document generation and UI consistency. |

---

## Error Logging Framework

The **ErrorLogService** class provides a unified logging system that captures and stores exceptions from Apex, Flows, and integrations.

### Highlights
- Automatically captures error context, user, and stack trace.  
- Compatible with Invocable Flow actions.  
- Logs entries to `Error_Log__c` with rich metadata (method, class, record context).  
- Optional Slack, email, or webhook notification integration (future enhancement).  

---

## Integration Registry

The **Integration Registry** provides metadata-based configuration for connecting to external APIs.

### Highlights
- Maps integration name → Named Credential → Auth method.  
- Defines endpoints, versioning, and headers declaratively.  
- Allows packages like Commerce or MagicPlan to connect dynamically without code edits.  
- Uses CMDT for easy deployment between orgs and sandboxes.

---

## Numbering Engine

A metadata-driven numbering framework powering Proposal, Invoice, and Contract sequencing across all Caliber packages.

### Example Configuration
| Field | Example |
|--------|----------|
| **Prefix__c** | `INV-` |
| **Padding__c** | `0000` |
| **Next_Number__c** | `1025` |
| **Reset_Annually__c** | `TRUE` |

---

## Development Standards

Caliber Core enforces consistent naming and packaging rules across all modules:
- All objects, fields, and Apex classes follow `Caliber` or `Core` prefixes.  
- All inter-package relationships use namespaced lookups (managed package compatible).  
- Trigger handlers follow the `BaseTrigger → Handler` pattern.  
- Shared constants and enums are stored in `CaliberConstants.cls`.  
- Global Apex classes are documented and versioned for SDK-style usage.

---

## Roadmap

- Integration Registry Lightning Editor.  
- Org-level configuration wizard (Setup App).  
- Enhanced telemetry and performance monitoring.  
- Cross-package dependency manager.  
- Declarative event framework for inter-module communication.

---

## License

This project is licensed under the terms described in the [LICENSE.md](./LICENSE.md) file.

© 2025 Caliber Technologies LLC  
For commercial or implementation inquiries, contact **dev@calibertech.net**
