---
name: View Model Platform Guide
description: The master guide for the view_model ecosystem. Start here to navigate to specific sub-skills.
---

# View Model Platform Guide

Welcome to the `view_model` ecosystem. This is the **Master Skill** that serves as an entry point for the three specialized capabilities provided in this package.

## 📂 Available Sub-Skills

While this skill provides a high-level overview, the detailed instructions are maintained in specialized sub-skills located in this directory.

### 1. [View Model Usage](usage/SKILL.md)
**Focus**: The core library (`view_model`).
- How to create ViewModels and Providers.
- How to consume them in Flutter Widgets.
- Using `vef` for dependency injection.
- Managing State with `StateViewModel`.

### 2. [Generator Usage](generator/SKILL.md)
**Focus**: The code generator (`view_model_generator`).
- Using `@genProvider` to automate boilerplate.
- Configuration options (singleton, custom keys).
- Best practices for generated code.

### 3. [Architecture Recommendation](architecture/SKILL.md)
**Focus**: System design.
- How to structure your entire app.
- "Everything is a ViewModel" pattern.
- Separating Logic, Data, and UI.

## 🔗 How to Use

- **If you are new**: Start by reading the [View Model Usage](usage/SKILL.md) to understand the basics.
- **If you are setting up a project**: Consult the [Architecture Recommendation](architecture/SKILL.md).
- **If you want to reduce code**: Learn the [Generator Usage](generator/SKILL.md).

---
*Note: Each of these sub-topics is also registered as an independent skill for direct access.*
