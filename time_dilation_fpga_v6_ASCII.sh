#!/bin/bash
# =============================================================================
# QUANTUM TIME DILATION SIMULATOR - FPGA
# Written By Andrea Giani
# Version for MSYS2/Windows/Linux - ASCII Version
# =============================================================================

# Configuration
CLOCK_RADIUS=8
MIN_TERMINAL_WIDTH=100
MIN_TERMINAL_HEIGHT=40
SIMULATION_FILE="quantum_states.dat"
FPGA_SIMULATION_TIME=5

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Update package manager only if necessary
if [ -z "$(find /var/lib/pacman/sync -mtime -1 -print -quit 2>/dev/null)" ]; then
	echo -e "${BLUE}Update repository...${NC}"
	pacman -Sy --noconfirm
fi

echo "Installing required packages..."
for pkg in base-devel bc; do
    if ! pacman -Q $pkg &> /dev/null; then
        pacman -S --needed --noconfirm $pkg
    fi
done

# Check terminal size
check_terminal_size() {
  if [ "$(tput cols)" -lt $MIN_TERMINAL_WIDTH ] || [ "$(tput lines)" -lt $MIN_TERMINAL_HEIGHT ]; then
    echo -e "${RED}Error: Terminal size too small!${NC}"
    echo -e "Minimum required: ${YELLOW}${MIN_TERMINAL_WIDTH}x${MIN_TERMINAL_HEIGHT}${NC}"
    echo -e "Current size: ${YELLOW}$(tput cols)x$(tput lines)${NC}"
    echo -e "${BLUE}Please resize your terminal and try again.${NC}"
    exit 1
  fi
}

# Simulate FPGA data generation
generate_fpga_data() {
  echo -e "${YELLOW}Initializing quantum FPGA simulation...${NC}"
  echo -e "${CYAN}Generating spacetime curvature data:${NC}"
  
  # Clear previous data
  > "$SIMULATION_FILE"
  
  # Simulate data generation with progress bar
  for i in {1..20}; do
    # Generate random velocity (0.1c to 0.99c)
    velocity=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); printf "%.4f\n", 0.1 + 0.89*rand() }')
    
    # Calculate time dilation factor: γ = 1/√(1 - v²/c²)
    gamma=$(awk -v v=$velocity 'BEGIN { 
      v2 = v*v;
      if (v2 >= 1) exit 1; 
      printf "%.6f\n", 1/sqrt(1 - v2)
    }')
    
    # Append to data file
    echo "$velocity:$gamma" >> "$SIMULATION_FILE"
    
    # Progress bar
    percent=$((i*5))
    bar=$(printf "%0.s█" $(seq 1 $((i*2))))
    space=$(printf "%0.s " $(seq 1 $((40-i*2))))
    
    printf "\r${GREEN}[%s%s] ${MAGENTA}%3d%%${NC} ${YELLOW}Sampling quantum states...${NC}" "$bar" "$space" "$percent"
    sleep 0.1
  done
  echo -e "\n\n${GREEN}Quantum simulation complete! Data ready for processing.${NC}\n"
}

# Draw dilated clock with color
draw_dilated_clock() {
  local velocity=$1
  local gamma=$2
  local clock_radius=$CLOCK_RADIUS
  local aspect_ratio=$(awk -v g=$gamma 'BEGIN { printf "%.2f", 0.5 + 0.5/g }')
  
  # Determine color based on velocity
  if (( $(echo "$velocity < 0.5" | bc -l) )); then
    color=$GREEN
  elif (( $(echo "$velocity < 0.8" | bc -l) )); then
    color=$YELLOW
  else
    color=$RED
  fi

  echo -e "\n${WHITE}VELOCITY: ${color}${velocity}c${NC} ${WHITE}DILATION: ${color}γ = ${gamma}${NC}"
  echo -e "${CYAN}Lab Frame${NC}   ${MAGENTA}Moving Frame${NC}\n"
  
  # Draw the two clocks side by side
  for ((y = -clock_radius; y <= clock_radius; y++)); do
    # Lab frame clock (perfect circle)
    line_lab=""
    for ((x = -clock_radius; x <= clock_radius; x++)); do
      distance=$(echo "scale=2; sqrt($x^2 + $y^2)" | bc)
      if (( $(echo "$distance >= $clock_radius - 0.5 && $distance <= $clock_radius + 0.5" | bc) )); then
        line_lab+="${BLUE}o${NC}"
      else
        line_lab+=" "
      fi
    done
    
    # Moving frame clock (ellipse)
    line_moving=""
    scaled_y=$(echo "scale=2; $y * $aspect_ratio" | bc)
    for ((x = -clock_radius; x <= clock_radius; x++)); do
      distance=$(echo "scale=2; sqrt($x^2 + $scaled_y^2)" | bc)
      if (( $(echo "$distance >= $clock_radius - 0.5 && $distance <= $clock_radius + 0.5" | bc) )); then
        line_moving+="${color}*${NC}"
      else
        line_moving+=" "
      fi
    done
    
    echo -e "$line_lab   ${WHITE}||${NC}   $line_moving"
  done
}

# Main simulation loop
main() {
  check_terminal_size
  clear
  
  echo -e "${GREEN}┌──────────────────────────────────────────────────────┐"
  echo -e "│   ${WHITE}QUANTUM TIME DILATION SIMULATOR (FPGA Enhanced)${GREEN}   │"
  echo -e "└──────────────────────────────────────────────────────┘${NC}"
  echo -e "${YELLOW}This simulation shows relativistic time dilation effects:"
  echo -e " - Left clock  ${BLUE}(Lab Frame)${YELLOW} shows normal time flow"
  echo -e " - Right clock ${MAGENTA}(Moving Frame)${YELLOW} shows dilated time"
  echo -e " - Color indicates velocity (${GREEN}low${YELLOW} → ${RED}high${YELLOW})${NC}\n"
  
  # Generate FPGA data if not available
  if [ ! -f "$SIMULATION_FILE" ] || [ ! -s "$SIMULATION_FILE" ]; then
    generate_fpga_data
    read -p "Press [Enter] to start visualization..."
  fi
  
  # Main visualization loop
  clear
  while true; do
    check_terminal_size
    clear
    
    echo -e "${WHITE}Quantum Time Dilation Simulation - Active Frames:${NC}"
    echo -e "${GREEN}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Process each data point
    while IFS=: read -r velocity gamma; do
      draw_dilated_clock "$velocity" "$gamma"
      echo -e "\n${GREEN}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
      sleep 0.5
    done < "$SIMULATION_FILE"
  done
}

# Start main process
main

