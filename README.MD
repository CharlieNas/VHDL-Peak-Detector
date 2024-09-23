# VHDL Peak Detector

A VHDL-based system for detecting and storing peak values, synthesised on an Artix-7 FPGA.

## Project Overview

* **Objective**: Design, implement, and test a peak detector system in VHDL, passing simulation test benches and synthesising correctly on an FPGA.
* **Components**:
  * **Data Processor**: Identifies and stores peak values within a stream of data.
  * **Command Processor**: Manages communication and data transfer between the FPGA and external systems.
* **Applications**:
  * High-speed communication systems
  * Satellite data processing

## Features

* **Peak Detection Algorithm**: Detects and stores peak values in a data sequence using an efficient state machine.
* **State Machine Architecture**: Ensures proper synchronisation and processing flow for accurate peak detection.
* **FPGA Synthesis**:
  * Successfully synthesised on an Artix-7 FPGA.
  * Resolved synthesis issues by eliminating inferred latches.

## System Architecture

### Data Processor

* **Architecture**:
  * *Finite State Machine*: Controls data flow and state transitions.
  * *Peak Detection*: Analyses data and identifies peaks within a sequence.
* **Signal Management**:
  * Two-phase protocol for data synchronisation.
  * Handles control signals for data requests and processing.

### Command Processor

* **Command Management**:
  * Validates and processes UART commands.
  * Controls data retrieval from the data processor.
* **Data Output**:
  * Converts detected peaks and surrounding data into ASCII format.
  * Supports detailed data display through UART transmission.

## Project Documentation

* 📄 **[Project Report](path/to/Group_12_reports.pdf)**: Comprehensive documentation of the design, implementation, and testing process.
* 📚 **Guidelines.pdf**: University-provided guide/documentation for the project.
