# Simple chat experiment

[a2ui]: https://github.com/a2ui-project/a2ui
[simple_chat_blueprint]: simple_chat.md
[inventory]: ../experiments/inventory.md

## Goal

This experiment aims to evaluate [a2ui] readiness for implementing applications enhanced with generated UI.

## Steps 

### 1. Setup

Create an experiment folder '<date>-<time>' with a README.md that describes the experiment details: 

- link to the used commit of a2ui
- used model name
- used model parameters (if any)

### 2. Generate

Generate a simple chat application following the [simple chat blueprint][simple_chat_blueprint] for three UI frameworks: React, Flutter and Jaspr.

Put the generated code into a `<ui-framework>` subdirectory. The subdirectory
should contain README.md with steps to start the app.

### 3. Evaluate

Execute primary CUJ for each UI framework and model combination, record a video, and place it into the 'videos' subdirectory. 

Put your observations and link to the corresponding video into the experiment README.md.

### 4. Add to inventory.

Add short description of the experiment and link to the experiment README.md into the [inventory][inventory].

Use H2 header "<date>-<time>" for each experiment. 
Create table that shows link to video, link to the README.md of framework and line count for each framework.
Use bullet points for the experiment details and findings.


