# On Device AI Projects

This repository contains hands-on projects exploring **on-device machine learning across Android, iOS, and Flutter**.

The goal of this series is to understand the **full ML deployment pipeline**:

1. Train models
2. Convert models for mobile inference
3. Run inference on-device
4. Understand threading, memory, and performance across platforms

---

# Project 1 — Simple Regression Model

A minimal neural network model deployed across three platforms.

The model takes a **single numeric input** and predicts a value using a trained regression model.

Example:

Input:
5

Output:
12.94

---

# ML Pipeline

Model training:

Deployment:

Platforms implemented:

- Android (Jetpack Compose)
- Flutter (Dart + Isolates)
- iOS (SwiftUI)

---

# Platform Implementations

## Android

Technology stack:

- Kotlin
- Jetpack Compose
- TensorFlow Lite
- Coroutines

Key concepts demonstrated:

- Direct ByteBuffer input
- Off-main-thread inference
- Coroutine dispatchers

---

## Flutter

Technology stack:

- Flutter
- Dart
- tflite_flutter
- Isolates

Key concepts demonstrated:

- Interpreter running in a worker isolate
- Message passing using SendPort
- Avoiding UI thread blocking

---

## iOS

Technology stack:

- Swift
- SwiftUI
- TensorFlowLiteSwift
- Grand Central Dispatch

Key concepts demonstrated:

- Data buffers for tensor input
- Background inference using DispatchQueue
- Main thread UI updates

---

# Core Concepts Learned

This project explores important systems-level topics for mobile ML:

- Threading models across platforms
- Memory buffers and tensor inputs
- Avoiding UI thread blocking
- Efficient model loading
- Interpreter lifecycle management

---

# Repository Structure

MobileAIProjects
│
├── SimpleAIAndroid
│
├── SimpleAIFlutter
│
└── SimpleAIiOS

Each platform runs the **same TensorFlow Lite model**.

---

# Future Projects

Upcoming projects will progressively introduce more complex ML tasks:

Project 2 — Image Classification  
Project 3 — Real-time Object Detection  
Project 4 — Camera Pipeline Optimization  
Project 5 — Quantization & Model Optimization  
Project 6 — Pose Detection  
Project 7 — OCR Pipeline  
Project 8 — Custom Vision Model

---

# Goal

The purpose of this repository is to develop deep expertise in:

- On-device AI
- Mobile runtime performance
- Native ML integration
- Cross-platform ML deployment
