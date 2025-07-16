#!/bin/bash
# =============================================================================
# QUANTUM TIME DILATION SIMULATOR - FPGA
# Written By Andrea Giani
# Version for MSYS2/Windows/Linux
# =============================================================================

# Update package manager only if necessary
echo "Updating package manager..."
pacman -Sy --noconfirm

echo "Installing required packages..."
for pkg in base-devel bc; do
    if ! pacman -Q $pkg &> /dev/null; then
        pacman -S --needed --noconfirm $pkg
    fi
done

# Force English locale for decimal numbers
export LC_NUMERIC="C"
export LANG="C"

# Global Configuration
FPGA_DEVICE="/dev/ttyUSB0"  # Adapt to your FPGA device
SIMULATION_TIME=3600        # Simulation time in seconds
ALTITUDE_STEP=1000          # Altitude step in meters
MAX_ALTITUDE=100000         # Maximum altitude
QUANTUM_RESOLUTION=1000000  # Quantum time resolution (nanoseconds)

# Physical Constants
EARTH_RADIUS=6371000        # Earth radius in meters
GRAVITY_EARTH=9.81          # Gravitational acceleration
SPEED_LIGHT=299792458       # Speed of light m/s
SCHWARZSCHILD_RADIUS=0.0089 # Earth's Schwarzschild radius in meters

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =============================================================================
# Function to generate the WebGL graph HTML file
# =============================================================================

generate_webgl_graph() {
    local results_file=$1
    local output_file="time_dilation_3d_curve_$(date +%Y%m%d_%H%M%S).html" # Changed output file name to reflect curve graph

    # Check if a results file is provided, otherwise find the most recent one
    if [ -z "$results_file" ]; then
        results_file=$(ls -t time_dilation_results_*.csv 2>/dev/null | head -1)
    fi

    if [ ! -f "$results_file" ]; then
        echo -e "${RED}[ERROR] Results file not found! Please run a simulation first.${NC}"
        return 1
    fi

    echo -e "${GREEN}[GRAPH] Creating 3D WebGL curve visualization...${NC}" # Updated message
    echo -e "${BLUE}Data taken from: $results_file${NC}"

    # Prepare data for JavaScript
    local js_data="["
    local first_line=true
    local max_altitude_val=0.0 # Use floating point for max values
    local max_diff_val=0.0     # Use floating point for max values

    # Read data to find max values for scaling and format for JS
    while IFS=',' read -r alt earth_time dilated_time quantum_time diff; do
        if [[ "$alt" == "Altitude(m)" ]]; then # Skip header explicitly
            continue
        fi

        # Clean and validate 'alt' (Altitude in meters)
        # Use 'tr -cd' to keep only digits and decimal point, then pass to bc
        local clean_alt=$(echo "$alt" | tr -cd '0-9.')
        local current_alt_km=$(echo "scale=0; if (\"$clean_alt\" == \"\") 0 else $clean_alt / 1000" | bc -l 2>/dev/null)
        current_alt_km=${current_alt_km:-0} # Default to 0 if bc fails or result is empty

        # Clean and validate 'diff' (Difference in ns)
        # Use 'tr -cd' to keep digits, decimal point, and minus sign, then pass to bc
        local clean_diff=$(echo "$diff" | tr -cd '0-9.-')
        local current_diff=$(echo "scale=2; if (\"$clean_diff\" == \"\" || $clean_diff < 0) 0 else $clean_diff" | bc -l 2>/dev/null)
        current_diff=${current_diff:-0.00} # Default to 0.00 if bc fails or result is empty
        
        # Skip this data point if both values are effectively zero after cleaning (e.g., malformed lines)
        # This check prevents adding empty or invalid data points to the graph
        if [ "$(echo "$current_alt_km == 0 && $current_diff == 0.00" | bc -l 2>/dev/null)" -eq 1 ] && [ "$first_line" = true ]; then
             continue # Skip initial zeroed-out line if it's the first data point
        fi

        if [ "$first_line" = false ]; then
            js_data+=","
        fi
        js_data+="{x:$current_alt_km, y:$current_diff}"
        first_line=false

        # Update max values using `[ $(bc) -eq 1 ]` for floating-point comparison
        # Suppress bc errors and check if bc output is '1' (true)
        local alt_compare_result=$(echo "$current_alt_km > $max_altitude_val" | bc -l 2>/dev/null)
        if [ "$alt_compare_result" = "1" ]; then
            max_altitude_val=$current_alt_km
        fi
        
        local diff_compare_result=$(echo "$current_diff > $max_diff_val" | bc -l 2>/dev/null)
        if [ "$diff_compare_result" = "1" ]; then
            max_diff_val=$current_diff
        fi
    done < "$results_file"
    js_data+="]"

    # If no data or max_diff_val is zero, set a default for scaling to avoid division by zero in JS
    if [ "$(echo "$max_diff_val == 0" | bc -l 2>/dev/null)" -eq 1 ]; then
        max_diff_val=1.0
    fi
    if [ "$(echo "$max_altitude_val == 0" | bc -l 2>/dev/null)" -eq 1 ]; then
        max_altitude_val=1.0
    fi

    # Create the HTML file with embedded JavaScript and Three.js
    cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Quantum Time Dilation - 3D Curve Visualization</title>
    <style>
        body { 
            margin: 0; 
            overflow: hidden; 
            background: linear-gradient(#1a1a1a, #0d0d1a);
            font-family: 'Arial', sans-serif;
        }
        canvas { display: block; }
        #info {
            position: absolute;
            top: 10px;
            width: 100%;
            text-align: center;
            color: #4af;
            font-size: 24px;
/* text-shadow: 0 0 10px rgba(100, 200, 255, 0.7);	*/
			text-shadow: 0 0 10px rgba(255, 100, 255, 0.7); /* For magenta */
            z-index: 100;
        }
        #legend {
            position: absolute;
            bottom: 20px;
            right: 20px;
            background: rgba(10, 10, 30, 0.7);
            padding: 15px;
            border-radius: 10px;
            color: #aef;
            font-size: 14px;
            border: 1px solid #46f;
        }
        .color-box {
            display: inline-block;
            width: 20px;
            height: 10px;
            margin-right: 5px;
        }
    </style>
</head>
<body>
    <div id="info">QUANTUM TIME DILATION VISUALIZATION</div>
    <div id="legend">
        <div><span class="color-box" style="background:#00f;"></span> Low Time Dilation</div>
        <div><span class="color-box" style="background:#0ff;"></span> Medium</div>
        <div><span class="color-box" style="background:#f0f;"></span> High Time Dilation</div>
    </div>
    
    <script type="importmap">
        {
            "imports": {
                "three": "https://unpkg.com/three@0.165.0/build/three.module.js",
                "three/addons/": "https://unpkg.com/three@0.165.0/examples/jsm/"
            }
        }
    </script>
    <script type="module">
        import * as THREE from 'three';
        import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

        // Data from Bash script
        const data = $js_data;
        const maxAltitude = $max_altitude_val;
        const maxDifference = $max_diff_val;

        // Scene setup
        const scene = new THREE.Scene();
        scene.fog = new THREE.FogExp2(0x0a0a20, 0.01);

        const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 10000);
        camera.position.set(maxAltitude * 0.7, maxDifference * 3, maxAltitude * 1.2);

        const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setClearColor(0x000000, 0);
        document.body.appendChild(renderer.domElement);

        // Ambient and directional lights
        const ambientLight = new THREE.AmbientLight(0x404060, 1.5);
        scene.add(ambientLight);
        
        const pointLight = new THREE.PointLight(0x4af, 1.5, 1000);
        pointLight.position.set(100, 200, 300);
        scene.add(pointLight);

        // Stars background
        const starGeometry = new THREE.BufferGeometry();
        const starCount = 5000;
        const starPositions = new Float32Array(starCount * 3);
        for (let i = 0; i < starCount * 3; i += 3) {
            starPositions[i] = (Math.random() - 0.5) * 2000;
            starPositions[i+1] = (Math.random() - 0.5) * 2000;
            starPositions[i+2] = (Math.random() - 0.5) * 2000;
        }
        starGeometry.setAttribute('position', new THREE.BufferAttribute(starPositions, 3));
        const starMaterial = new THREE.PointsMaterial({
            color: 0xffffff,
            size: 1.5,
            transparent: true
        });
        const stars = new THREE.Points(starGeometry, starMaterial);
        scene.add(stars);

        // Create curve geometry
        const curvePoints = [];
        const colors = [];
        const colorGradient = [
            new THREE.Color(0x0000ff),  // Blue (low dilation)
            new THREE.Color(0x00ffff),  // Cyan
            new THREE.Color(0xff00ff)   // Magenta (high dilation)
        ];

        data.forEach((d, index) => {
            const alt = d.x;
            const diff = d.y;
            
            // 3D position: x=altitude, y=time dilation, z=sin wave for depth
            const zPos = Math.sin(alt * 0.01) * maxAltitude * 0.2;
            curvePoints.push(new THREE.Vector3(alt, diff * 5, zPos));
            
            // Color gradient based on dilation value
            const colorFactor = diff / maxDifference;
            const color = new THREE.Color().copy(colorGradient[0]);
            color.lerp(colorGradient[1], colorFactor * 2);
            if (colorFactor > 0.5) {
                color.lerp(colorGradient[2], (colorFactor - 0.5) * 2);
            }
            colors.push(color.r, color.g, color.b);
        });

        // Create the curve geometry
        const curveGeometry = new THREE.BufferGeometry().setFromPoints(curvePoints);
        curveGeometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
        
        const curveMaterial = new THREE.LineBasicMaterial({
            vertexColors: true,
            linewidth: 5,
            transparent: true,
            opacity: 0.9
        });
        
        const curveLine = new THREE.Line(curveGeometry, curveMaterial);
        scene.add(curveLine);

        // Add glowing points along the curve
        const pointsGeometry = new THREE.BufferGeometry().setFromPoints(curvePoints);
        const pointMaterial = new THREE.PointsMaterial({
            color: 0xffffff,
            size: 4,
            sizeAttenuation: true,
            transparent: true,
            blending: THREE.AdditiveBlending
        });
        
        const points = new THREE.Points(pointsGeometry, pointMaterial);
        scene.add(points);

		// Add Earth model at origin - Enhanced brightness version
		const earthGeometry = new THREE.SphereGeometry(20, 64, 64);  // Increased size
		const earthTexture = new THREE.TextureLoader().load('https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg');

		// Brighter material with self-illumination
		const earthMaterial = new THREE.MeshPhongMaterial({
			map: earthTexture,
			specular: 0xffffff,  // Brighter specular highlights
			shininess: 100,      // More focused highlights
			emissive: 0x224488,  // Blue self-illumination
			emissiveIntensity: 0.8
		});

		const earth = new THREE.Mesh(earthGeometry, earthMaterial);
		scene.add(earth);

		// Enhanced atmosphere with stronger glow
		const atmosGeometry = new THREE.SphereGeometry(20.5, 64, 64);
		const atmosMaterial = new THREE.MeshPhongMaterial({
			color: 0x88ddff,     // Brighter blue
			transparent: true,
			opacity: 0.6,        // Less transparent
			emissive: 0x4488ff,  // Glowing effect
			emissiveIntensity: 0.6,
			side: THREE.BackSide // Render inside out
		});

		const atmosphere = new THREE.Mesh(atmosGeometry, atmosMaterial);
		scene.add(atmosphere);

		// Add core glow effect
		const coreGlowGeometry = new THREE.SphereGeometry(18, 32, 32);
		const coreGlowMaterial = new THREE.MeshBasicMaterial({
			color: 0x88aaff,
			transparent: true,
			opacity: 0.3,
			blending: THREE.AdditiveBlending
		});

		const coreGlow = new THREE.Mesh(coreGlowGeometry, coreGlowMaterial);
		earth.add(coreGlow);

		// Add bright specular highlight
		const highlightGeometry = new THREE.SphereGeometry(21, 32, 32);
		const highlightMaterial = new THREE.MeshBasicMaterial({
			color: 0xffffff,
			transparent: true,
			opacity: 0.2,
			blending: THREE.AdditiveBlending
		});

		const highlight = new THREE.Mesh(highlightGeometry, highlightMaterial);
		scene.add(highlight);

		// Add directional light specifically for Earth
		const earthLight = new THREE.PointLight(0x88ccff, 3, 200);
		earthLight.position.set(50, 50, 50);
		scene.add(earthLight);

        // Add coordinate system
        const axesHelper = new THREE.AxesHelper(Math.max(maxAltitude, maxDifference) * 1.2);
        scene.add(axesHelper);

        // Add labels
		const makeTextSprite = (text, color) => {
			const canvas = document.createElement('canvas');
			const ctx = canvas.getContext('2d');
			
			// Measure text to properly size the canvas
			ctx.font = 'Bold 26px Arial';
			const width = ctx.measureText(text).width + 40;
			const height = 50;
			canvas.width = width;
			canvas.height = height;
			
			// Redraw with new dimensions
			ctx.font = 'Bold 26px Arial';
			
			// Add shadow for better readability
			ctx.shadowColor = '#000';
			ctx.shadowBlur = 8;
			ctx.shadowOffsetX = 2;
			ctx.shadowOffsetY = 2;
			
			// Main text
			ctx.fillStyle = color;
			ctx.fillText(text, 20, 35);
			
			// Outline to increase contrast
			ctx.strokeStyle = '#ffffff';
			ctx.lineWidth = 1;
			ctx.strokeText(text, 20, 35);
			
			const texture = new THREE.CanvasTexture(canvas);
			const material = new THREE.SpriteMaterial({ 
				map: texture,
				transparent: true
			});
			
			const sprite = new THREE.Sprite(material);
			sprite.scale.set(width * 0.5, height * 0.5, 1);
			return sprite;
		};

		const altLabel = makeTextSprite('ALTITUDE (km)', '#00ffff');  // Bright Cyan
        altLabel.position.set(maxAltitude * 0.8, -10, 0);
        scene.add(altLabel);

		const timeLabel = makeTextSprite('TIME DILATION (ns)', '#f8a');
        timeLabel.position.set(0, maxDifference * 5, 0);
        timeLabel.rotation.y = -Math.PI / 2;
        scene.add(timeLabel);

        // Controls
        const controls = new OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.05;
        controls.rotateSpeed = 0.5;

        // Animation
        let time = 0;
        function animate() {
            requestAnimationFrame(animate);
            time += 0.01;
            
            // Animate points
            points.rotation.y = time * 0.1;
            curveLine.rotation.y = time * 0.1;
            
            // Update camera position slightly for floating effect
            camera.position.x = maxAltitude * 0.7 + Math.sin(time * 0.2) * 50;
            camera.position.z = maxAltitude * 1.2 + Math.cos(time * 0.3) * 50;
            
            controls.update();
            renderer.render(scene, camera);
        }
        animate();

        // Handle window resize
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}[GRAPH] File created: ${YELLOW}$output_file${NC}"

    # --- Automatic file opening in browser ---
    case "$(uname -s)" in
        CYGWIN*|MINGW32*|MSYS*) # Windows (MSYS2, Git Bash)
            start "$output_file"
            ;;
        Linux*) # Linux
            xdg-open "$output_file" || sensible-browser "$output_file" || google-chrome "$output_file" || firefox "$output_file" || echo -e "${YELLOW}[WARNING] Could not automatically open browser. Open manually: $output_file${NC}"
            ;;
        Darwin*) # macOS
            open "$output_file"
            ;;
        *) # Other operating systems
            echo -e "${YELLOW}[WARNING] Unknown OS detected. Open the file manually in your browser: ${NC}${output_file}"
            ;;
    esac

    echo -e "${BLUE}Open the file in your browser to view the 3D curve graph.${NC}" # Updated message
}

# =============================================================================
# MATHEMATICAL FUNCTIONS FOR TIME DILATION
# =============================================================================

calculate_time_dilation() {
    local altitude=$1
    local earth_surface_time=$2 # This should be the time interval on the Earth's surface
    
    local r_earth=$EARTH_RADIUS
    local r_altitude=$(echo "scale=15; $EARTH_RADIUS + $altitude" | bc -l)
    local rs=$SCHWARZSCHILD_RADIUS # Earth's Schwarzschild radius
    
    # Calculate the dilation factor for the surface
    local factor_surface
    factor_surface=$(echo "scale=15; sqrt(1 - ($rs / $r_earth))" | bc -l 2>/dev/null)
    
    # Calculate the dilation factor for the altitude
    local factor_altitude
    factor_altitude=$(echo "scale=15; sqrt(1 - ($rs / $r_altitude))" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$factor_surface" ] || [ -z "$factor_altitude" ]; then
        echo $earth_surface_time
        return
    fi
    
    # Calculate the ratio between time at altitude and time on the surface
    # time_ratio = (factor_surface / factor_altitude)
    local time_ratio
    time_ratio=$(echo "scale=15; $factor_surface / $factor_altitude" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$time_ratio" ]; then
        echo $earth_surface_time
        return
    fi
    
    # Dilated time at altitude (will be slightly greater than earth_surface_time)
    local dilated_time
    dilated_time=$(echo "scale=10; $earth_surface_time * $time_ratio" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$dilated_time" ]; then
        echo $earth_surface_time
        return
    fi
    
    echo $dilated_time
}

quantum_time_discretization() {
    local continuous_time=$1
    
    # Quantum discretization of time (Planck time units)
    # Simulates the "granular" nature of time
    local planck_time="5.39e-44" # seconds
    
    local quantum_units
    quantum_units=$(echo "scale=0; $continuous_time / $planck_time" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$quantum_units" ]; then
        echo $continuous_time
        return
    fi
    
    local discretized_time
    discretized_time=$(echo "scale=15; $quantum_units * $planck_time" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$discretized_time" ]; then
        echo $continuous_time
        return
    fi
    
    echo $discretized_time
}

# =============================================================================
# FPGA INTERFACE
# =============================================================================

init_fpga() {
    echo -e "${BLUE}[FPGA] Initializing device...${NC}"
    
    # Check if FPGA device is available
    if [ ! -c "$FPGA_DEVICE" ]; then
        echo -e "${YELLOW}[WARNING] FPGA device not found. Simulation mode enabled.${NC}"
        FPGA_MODE="simulation"
    else
        echo -e "${GREEN}[FPGA] Device connected: $FPGA_DEVICE${NC}"
        FPGA_MODE="hardware"
        
        # Configure serial parameters
        stty -F $FPGA_DEVICE 115200 cs8 -cstopb -parenb
    fi
}

send_fpga_command() {
    local command=$1
    local altitude=$2
    local time_factor=$3
    
    if [ "$FPGA_MODE" == "hardware" ]; then
        # Send command to FPGA
        echo "CMD:$command,ALT:$altitude,TIME:$time_factor" > $FPGA_DEVICE
        
        # Read response
        local response=$(timeout 1s cat $FPGA_DEVICE)
        echo "$response"
    else
        # Simulate FPGA response
        local sim_response="SIM_OK:ALT=$altitude,FACTOR=$time_factor"
        echo "$sim_response"
    fi
}

# =============================================================================
# MAIN SIMULATION
# =============================================================================

run_time_simulation() {
    local current_altitude=0
    local base_time=0
    local results_file="time_dilation_results_$(date +%Y%m%d_%H%M%S).csv"
    
    echo -e "${GREEN}[SIM] Starting time dilation simulation...${NC}"
    echo "Altitude(m),Earth_Time(s),Dilated_Time(s),Quantum_Time(s),Difference(ns)" > $results_file
    
    while [ $current_altitude -le $MAX_ALTITUDE ]; do
        # Calculate time dilation
        local earth_time=$(echo "scale=10; $base_time + 1.0" | bc -l)
        local dilated_time=$(calculate_time_dilation $current_altitude $earth_time)
        local quantum_time=$(quantum_time_discretization $dilated_time)
        
        # Calculate difference in nanoseconds
        local time_diff
        time_diff=$(echo "scale=2; ($dilated_time - $earth_time) * 1000000000" | bc -l 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$time_diff" ]; then
            time_diff="0.00"
        fi
        
        # Send data to FPGA
        local fpga_response=$(send_fpga_command "TIME_CALC" $current_altitude $dilated_time)
        
        # Save results
        echo "$current_altitude,$earth_time,$dilated_time,$quantum_time,$time_diff" >> $results_file
        
        # Convert for printf (replace dots with commas if necessary for some locales, though LC_NUMERIC="C" should handle it)
        # Keeping consistent with original script's conversion for display
        local earth_time_display=$(echo $earth_time | sed 's/\./,/g')
        local dilated_time_display=$(echo $dilated_time | sed 's/\./,/g')
        local time_diff_display=$(echo $time_diff | sed 's/\./,/g')
        
        # Real-time output
        printf "${BLUE}Alt: %6d m${NC} | ${GREEN}Earth: %s s${NC} | ${YELLOW}Dilated: %s s${NC} | ${RED}Diff: %s ns${NC}\n" \
               $current_altitude "$earth_time_display" "$dilated_time_display" "$time_diff_display"
        
        # Increment altitude and base time
        current_altitude=$((current_altitude + ALTITUDE_STEP))
        base_time=$(echo "scale=10; $base_time + 0.1" | bc -l 2>/dev/null)
        
        # Validity check
        if [ $? -ne 0 ] || [ -z "$base_time" ]; then
            base_time="0.1"
        fi
        
        # Pause for visualization
        sleep 0.1
    done
    
    echo -e "${GREEN}[SIM] Simulation completed. Results saved to: $results_file${NC}"
}

# =============================================================================
# RESULTS ANALYSIS
# =============================================================================

analyze_results() {
    local results_file=$1
    
    echo -e "${BLUE}[ANALYSIS] Processing data...${NC}"
    
    # Find most recent results file if not specified
    if [ -z "$results_file" ]; then
        results_file=$(ls -t time_dilation_results_*.csv 2>/dev/null | head -1)
    fi
    
    if [ ! -f "$results_file" ]; then
        echo -e "${RED}[ERROR] Results file not found!${NC}"
        return 1
    fi
    
    # Statistical analysis
    local max_diff=$(tail -n +2 "$results_file" | cut -d',' -f5 | sort -n | tail -1)
    local avg_diff=$(tail -n +2 "$results_file" | cut -d',' -f5 | awk '{sum+=$1} END {if(NR>0) print sum/NR; else print 0}')
    
    # Check if values are valid
    if [ -z "$max_diff" ]; then max_diff="0.00"; fi
    if [ -z "$avg_diff" ]; then avg_diff="0.00"; fi
    
    echo -e "${GREEN}=== ANALYSIS RESULTS ===${NC}"
    echo -e "Maximum difference: ${YELLOW}$max_diff ns${NC}"
    echo -e "Average difference: ${YELLOW}$(printf "%.2f" $avg_diff 2>/dev/null || echo $avg_diff) ns${NC}"
    
    # Generate ASCII graph
    generate_ascii_graph "$results_file"
}

generate_ascii_graph() {
    local file=$1
    local max_val=50  # Graph scale
    
    echo -e "\n${BLUE}=== TIME DILATION GRAPH ===${NC}"
    echo "Altitude (km) vs Time Difference (ns)"
    
    tail -n +2 "$file" | while IFS=',' read -r alt earth_time dilated_time quantum_time diff; do
        local alt_km=$((alt / 1000))
        local bar_length=$(echo "scale=0; $diff * $max_val / 100" | bc -l 2>/dev/null)
        
        # Check validity
        if [ $? -ne 0 ] || [ -z "$bar_length" ] || [ "$bar_length" -lt 0 ]; then
            bar_length=0
        fi
        
        # Limit bar length
        if [ "$bar_length" -gt "$max_val" ]; then
            bar_length=$max_val
        fi
        
        # Generate bar
        local bar=""
        for ((i=0; i<bar_length; i++)); do
            bar+="█"
        done
        
        # Display with error checking
        printf "%3d km |%-${max_val}s| %s ns\n" $alt_km "$bar" "${diff:-0.00}"
    done
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    echo -e "\n${GREEN}=== QUANTUM TIME DILATION SIMULATOR ===${NC}"
    echo -e "${BLUE}1.${NC} Start full simulation"
    echo -e "${BLUE}2.${NC} Analyze existing results"
    echo -e "${BLUE}3.${NC} Test FPGA connection"
    echo -e "${BLUE}4.${NC} Quick simulation (10 points)"
    echo -e "${BLUE}5.${NC} Show physics theory"
    echo -e "${BLUE}6.${NC} Generate WebGL graph"
    echo -e "${BLUE}7.${NC} Exit"
    echo -n "Choose option: "
}

quick_simulation() {
    echo -e "${YELLOW}[QUICK] Running quick simulation...${NC}"
    local original_step=$ALTITUDE_STEP
    local original_max=$MAX_ALTITUDE
    
    ALTITUDE_STEP=10000
    MAX_ALTITUDE=100000
    
    run_time_simulation
    
    ALTITUDE_STEP=$original_step
    MAX_ALTITUDE=$original_max
}

show_theory() {
    echo -e "\n${GREEN}=== PHYSICS THEORY ===${NC}"
    echo -e "${BLUE}Gravitational Time Dilation:${NC}"
    echo "- Time runs slower in strong gravitational fields"
    echo "- Formula: Δt = t₀ × √(1 - 2GM/rc²)"
    echo "- Moving away from Earth, time speeds up"
    echo ""
    echo -e "${BLUE}Quantum Aspects:${NC}"
    echo "- Planck time: 5.39×10⁻⁴⁴ seconds"
    echo "- Possible quantum discretization of time"
    echo "- The 'present' as a quantum superposition"
    echo ""
    echo -e "${BLUE}FPGA Implementation:${NC}"
    echo "- Parallel calculation of time dilations"
    echo "- Real-time simulation of relativistic effects"
    echo "- Visualization of 'time fog'"
}

test_fpga() {
    echo -e "${BLUE}[TEST] Checking FPGA connection...${NC}"
    init_fpga
    
    if [ "$FPGA_MODE" == "hardware" ]; then
        local test_response=$(send_fpga_command "TEST" 0 1.0)
        echo -e "${GREEN}[TEST] FPGA response: $test_response${NC}"
    else
        echo -e "${YELLOW}[TEST] Simulation mode active${NC}"
    fi
}

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    # Check dependencies
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}[ERROR] bc not installed. Install with: pacman -S bc${NC}"
        exit 1
    fi
    
    # Initialize FPGA
    init_fpga
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                run_time_simulation
                ;;
            2)
                echo -n "Results file (Enter for latest): "
                read -r file
                analyze_results "$file"
                ;;
            3)
                test_fpga
                ;;
            4)
                quick_simulation
                ;;
            5)
                show_theory
                ;;
            6)
                generate_webgl_graph ""
                ;;
            7)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        
        echo -n "Press ENTER to continue..."
        read -r
    done
}

# Start program
main "$@"
