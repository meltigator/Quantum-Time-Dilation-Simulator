# Quantum Time Dilation Simulator - FPGA Project

Bridging Einstein's Relativity with Quantum Mechanics

I've developed an open-source FPGA-based simulator that visualizes one of physics' most mind-bending phenomena: how gravity warps time itself. This project demonstrates how time accelerates as we move away from Earth - an effect measured in nanoseconds but with profound cosmic implications.

Why this matters:

    Combines general relativity (gravitational time dilation) with quantum mechanics (Planck-scale discretization)

    Makes tangible Einstein's prediction that clocks run faster in orbit (validated by GPS satellites)

    Explores cutting-edge theories about time's quantum nature

Technical highlights:

1. FPGA-accelerated physics engine

   - Real-time dilation calculations using √(1 - 2GM/rc²)

   - Quantum time discretization at 5.39×10⁻⁴⁴s resolution

   - Hardware/simulation dual modes

2. Immersive visualization

    - WebGL 3D cosmic environment

    - Animated spacetime curvature models

    - Dynamic altitude vs. time difference plots

3. Cross-platform framework

    - MSYS2/Windows/Linux compatible

    - Bash control center with interactive menus

    - CSV data pipeline for analysis

The science in action:
The simulator reveals how at 10,000m altitude, time flows ~30 nanoseconds/day faster than at sea level - a tiny but measurable effect that impacts GPS systems and proves time isn't absolute.

Perfect for STEM educators, physics enthusiasts, and engineers interested in:

    Relativistic computing

    Quantum gravity concepts

    FPGA scientific applications

    Physics visualization

----------------------------------
ASCII VERSION
----------------------------------

Added enhanced version of your script with improved visualization using ASCII art ellipses to represent time dilation effects. The key improvements include:

    Dynamic elliptical visualization showing distortion effects

    Color-coded output for better readability

    Improved layout and information display

    Better terminal handling with resize detection

    Progress bar during FPGA simulation phase

Key improvements in this version:

    Enhanced Visualization:

    Dual-frame display showing both lab and moving reference frames

    Elliptical distortion representing relativistic effects

    Color-coded output based on velocity (green → yellow → red)

    User Experience:

        Terminal size checking with helpful error messages

        FPGA simulation progress bar

        Clear section headers and instructions

        Improved spacing and alignment

    Physics Accuracy:

        Proper Lorentz factor calculation γ = 1/√(1 - v²/c²)

        Velocity range from 0.1c to 0.99c

        Aspect ratio scaling based on time dilation factor

    Performance:

        Optimized calculations using awk instead of bc

        Pre-generated data set for smoother animation

        Efficient screen drawing

    New Features:

        Progress bar during data generation

        Auto-detection of existing data files

        Better error handling

        Color-coded velocity information

The visualization shows:

    Left (Blue): Lab frame reference clock (perfect circle)

    Right (Color-coded): Moving frame showing time dilation effects

    Elliptical distortion increases with velocity

    Color changes from green to red as velocity increases

The script automatically checks terminal size, generates simulation data if needed, and runs a continuous visualization of relativistic time dilation effects.



#QuantumPhysics #FPGA #Relativity #STEM #PhysicsSimulation #TimeDilation #OpenSource #ScientificComputing #Engineering
