# Patrik Baleka – Programming Portfolio

This repository contains selected examples of my work in software development, system design, and applied algorithms.  
My focus areas include C++ (evolutionary algorithms, library extensions) and Godot/GDScript (modular game systems).

The repository is divided into two main sections:

- **C++ – Extensions of the Galgo evolutionary algorithm library (MIT license)**
- **Godot – Modular systems from the ToD: Incremental project (safe, asset‑free code samples)**

---

## 1. C++ – Galgo Library Extensions

As part of my master's thesis, I extended the open‑source **Galgo** library (MIT license) with new evolutionary operators, mutation strategies, and stopping criteria.  
The goal was to improve evolutionary diversity and enable more flexible optimization workflows.

### Implemented Features
This repository contains **only my own code**, not the full Galgo library.

#### New crossover operators
- OX (Ordered Crossover)  
- CX (Cycle Crossover)  
- Even–Odd crossover  

#### New mutation operators
- Gaussian mutation  
- Swap mutation  
- Inversion mutation  

### 📄 Licensing
The original Galgo library is MIT‑licensed.  
All files in this repository are either:
- my own implementations, or  
- small contextual snippets that retain the original MIT copyright header.

---

## 2. Godot – Modular Systems (GDScript)

This section contains **safe, isolated code samples** from my project *ToD: Incremental*.  
No assets, no proprietary gameplay logic, and no content from *ToD: Exodus / Project Kondela* is included.

### Save/Load Manager (old → new)
A refactoring example demonstrating:

- explicit subsystem loading (old version)  
- generic, registry‑based loading (new version)  

This showcases:
- modularity  
- refactoring  
- cleaner architecture  
- maintainability improvements  

### Actions Manager
A standalone system for:

- action registration  
- input processing  
- subsystem dispatching  

Again, this is purely technical code without any commercial content.

## Purpose of This Repository

This repository serves as a **technical portfolio**, demonstrating:

- ability to extend and modify C++ libraries  
- understanding of evolutionary algorithms  
- clean, maintainable system design  
- experience with Godot and GDScript  
- practical refactoring and modular architecture  

No commercial assets or proprietary game content are included.
