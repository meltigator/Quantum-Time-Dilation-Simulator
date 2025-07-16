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

# Forza locale inglese per numeri decimali
export LC_NUMERIC="C"
export LANG="C"

# Configurazione globale
FPGA_DEVICE="/dev/ttyUSB0"  # Adatta al tuo dispositivo FPGA
SIMULATION_TIME=3600        # Tempo simulazione in secondi
ALTITUDE_STEP=1000          # Step altitudine in metri
MAX_ALTITUDE=100000         # Altitudine massima
QUANTUM_RESOLUTION=1000000  # Risoluzione temporale quantistica (nanosec)

# Costanti fisiche
EARTH_RADIUS=6371000        # Raggio Terra in metri
GRAVITY_EARTH=9.81          # Accelerazione gravitazionale
SPEED_LIGHT=299792458       # Velocità della luce m/s
SCHWARZSCHILD_RADIUS=0.0089 # Raggio di Schwarzschild Terra in metri

# Colori per output
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
    local output_file="time_dilation_3d_bar_graph_$(date +%Y%m%d_%H%M%S).html"

    # Check if a results file is provided, otherwise find the most recent one
    if [ -z "$results_file" ]; then
        results_file=$(ls -t time_dilation_results_*.csv 2>/dev/null | head -1)
    fi

    if [ ! -f "$results_file" ]; then
        echo -e "${RED}[ERROR] File risultati non trovato! Esegui prima una simulazione.${NC}"
        return 1
    fi

    echo -e "${GREEN}[GRAFICO] Creazione del grafico WebGL 3D a barre...${NC}"
    echo -e "${BLUE}Dati presi da: $results_file${NC}"

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
/*          text-shadow: 0 0 10px rgba(100, 200, 255, 0.7);	*/
			text-shadow: 0 0 10px rgba(255, 100, 255, 0.7); /* Per il magenta */
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

        // Add Earth model at origin
        const earthGeometry = new THREE.SphereGeometry(15, 32, 32);
        const earthTexture = new THREE.TextureLoader().load('https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg');
        const earthMaterial = new THREE.MeshPhongMaterial({
            map: earthTexture,
            specular: 0x333333,
            shininess: 5
        });
        const earth = new THREE.Mesh(earthGeometry, earthMaterial);
        scene.add(earth);
        
        // Add atmosphere
        const atmosGeometry = new THREE.SphereGeometry(15.5, 32, 32);
        const atmosMaterial = new THREE.MeshPhongMaterial({
            color: 0x3399ff,
            transparent: true,
            opacity: 0.2
        });
        const atmosphere = new THREE.Mesh(atmosGeometry, atmosMaterial);
        scene.add(atmosphere);

        // Add coordinate system
        const axesHelper = new THREE.AxesHelper(Math.max(maxAltitude, maxDifference) * 1.2);
        scene.add(axesHelper);

        // Add labels
//      const makeTextSprite = (text, color) => {
//          const canvas = document.createElement('canvas');
//          const ctx = canvas.getContext('2d');
//          ctx.font = 'Bold 24px Arial';
//          ctx.fillStyle = color;
//          ctx.fillText(text, 10, 40);
//          ctx.strokeStyle = '#000';
//          ctx.lineWidth = 4;
//          ctx.strokeText(text, 10, 40);
            
//          const texture = new THREE.CanvasTexture(canvas);
//          const material = new THREE.SpriteMaterial({ map: texture });
//          const sprite = new THREE.Sprite(material);
//          sprite.scale.set(100, 40, 1);
//          return sprite;
//      };

		const makeTextSprite = (text, color) => {
			const canvas = document.createElement('canvas');
			const ctx = canvas.getContext('2d');
			
			// Misura il testo per dimensionare correttamente il canvas
			ctx.font = 'Bold 26px Arial';
			const width = ctx.measureText(text).width + 40;
			const height = 50;
			canvas.width = width;
			canvas.height = height;
			
			// Ridisegna con le nuove dimensioni
			ctx.font = 'Bold 26px Arial';
			
			// Aggiungi ombra per migliorare la leggibilità
			ctx.shadowColor = '#000';
			ctx.shadowBlur = 8;
			ctx.shadowOffsetX = 2;
			ctx.shadowOffsetY = 2;
			
			// Testo principale
			ctx.fillStyle = color;
			ctx.fillText(text, 20, 35);
			
			// Contorno per aumentare il contrasto
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

//      const altLabel = makeTextSprite('ALTITUDE (km)', '#4af');
		const altLabel = makeTextSprite('ALTITUDE (km)', '#00ffff');  // Ciano brillante
        altLabel.position.set(maxAltitude * 0.8, -10, 0);
        scene.add(altLabel);

//      const timeLabel = makeTextSprite('TIME DILATION (ns)', '#f8a');
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

    echo -e "${GREEN}[GRAFICO] File creato: ${YELLOW}$output_file${NC}"

    # --- Apertura automatica del file nel browser ---
    case "$(uname -s)" in
        CYGWIN*|MINGW32*|MSYS*) # Windows (MSYS2, Git Bash)
            start "$output_file"
            ;;
        Linux*) # Linux
            xdg-open "$output_file" || sensible-browser "$output_file" || google-chrome "$output_file" || firefox "$output_file" || echo -e "${YELLOW}[WARNING] Impossibile aprire automaticamente il browser. Apri manualmente: $output_file${NC}"
            ;;
        Darwin*) # macOS
            open "$output_file"
            ;;
        *) # Altri sistemi operativi
            echo -e "${YELLOW}[WARNING] Rilevato OS sconosciuto. Apri manualmente il file nel tuo browser: ${NC}${output_file}"
            ;;
    esac

    echo -e "${BLUE}Apri il file nel tuo browser per visualizzare il grafico 3D a barre.${NC}"
}

# =============================================================================
# FUNZIONI MATEMATICHE PER DILATAZIONE TEMPORALE
# =============================================================================

calculate_time_dilation() {
    local altitude=$1
    local earth_surface_time=$2 # Questo dovrebbe essere l'intervallo di tempo sulla superficie terrestre
    
    local r_earth=$EARTH_RADIUS
    local r_altitude=$(echo "scale=15; $EARTH_RADIUS + $altitude" | bc -l)
    local rs=$SCHWARZSCHILD_RADIUS # Raggio di Schwarzschild della Terra
    
    # Calcola il fattore di dilatazione per la superficie
    local factor_surface
    factor_surface=$(echo "scale=15; sqrt(1 - ($rs / $r_earth))" | bc -l 2>/dev/null)
    
    # Calcola il fattore di dilatazione per l'altitudine
    local factor_altitude
    factor_altitude=$(echo "scale=15; sqrt(1 - ($rs / $r_altitude))" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$factor_surface" ] || [ -z "$factor_altitude" ]; then
        echo $earth_surface_time
        return
    fi
    
    # Calcola il rapporto tra il tempo in altitudine e il tempo sulla superficie
    # time_ratio = (factor_surface / factor_altitude)
    local time_ratio
    time_ratio=$(echo "scale=15; $factor_surface / $factor_altitude" | bc -l 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$time_ratio" ]; then
        echo $earth_surface_time
        return
    fi
    
    # Tempo dilatato in altitudine (sarà leggermente maggiore di earth_surface_time)
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
    
    # Discretizzazione quantistica del tempo (Planck time units)
    # Simula la natura "granulare" del tempo
    local planck_time="5.39e-44" # secondi
    
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
# INTERFACCIA FPGA
# =============================================================================

init_fpga() {
    echo -e "${BLUE}[FPGA] Inizializzazione dispositivo...${NC}"
    
    # Controlla se dispositivo FPGA è disponibile
    if [ ! -c "$FPGA_DEVICE" ]; then
        echo -e "${YELLOW}[WARNING] Dispositivo FPGA non trovato. Modalità simulazione.${NC}"
        FPGA_MODE="simulation"
    else
        echo -e "${GREEN}[FPGA] Dispositivo connesso: $FPGA_DEVICE${NC}"
        FPGA_MODE="hardware"
        
        # Configura parametri seriali
        stty -F $FPGA_DEVICE 115200 cs8 -cstopb -parenb
    fi
}

send_fpga_command() {
    local command=$1
    local altitude=$2
    local time_factor=$3
    
    if [ "$FPGA_MODE" == "hardware" ]; then
        # Invia comando all'FPGA
        echo "CMD:$command,ALT:$altitude,TIME:$time_factor" > $FPGA_DEVICE
        
        # Leggi risposta
        local response=$(timeout 1s cat $FPGA_DEVICE)
        echo $response
    else
        # Simula risposta FPGA
        local sim_response="SIM_OK:ALT=$altitude,FACTOR=$time_factor"
        echo $sim_response
    fi
}

# =============================================================================
# SIMULAZIONE PRINCIPALE
# =============================================================================

run_time_simulation() {
    local current_altitude=0
    local base_time=0
    local results_file="time_dilation_results_$(date +%Y%m%d_%H%M%S).csv"
    
    echo -e "${GREEN}[SIM] Avvio simulazione dilatazione temporale...${NC}"
    echo "Altitude(m),Earth_Time(s),Dilated_Time(s),Quantum_Time(s),Difference(ns)" > $results_file
    
    while [ $current_altitude -le $MAX_ALTITUDE ]; do
        # Calcola dilatazione temporale
        local earth_time=$(echo "scale=10; $base_time + 1.0" | bc -l)
        local dilated_time=$(calculate_time_dilation $current_altitude $earth_time)
        local quantum_time=$(quantum_time_discretization $dilated_time)
        
        # Calcola differenza in nanosecondi
        local time_diff
        time_diff=$(echo "scale=2; ($dilated_time - $earth_time) * 1000000000" | bc -l 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$time_diff" ]; then
            time_diff="0.00"
        fi
        
        # Invia dati all'FPGA
        local fpga_response=$(send_fpga_command "TIME_CALC" $current_altitude $dilated_time)
        
        # Salva risultati
        echo "$current_altitude,$earth_time,$dilated_time,$quantum_time,$time_diff" >> $results_file
        
        # Converti per printf (sostituisci punti con virgole se necessario)
        local earth_time_display=$(echo $earth_time | sed 's/\./,/g')
        local dilated_time_display=$(echo $dilated_time | sed 's/\./,/g')
        local time_diff_display=$(echo $time_diff | sed 's/\./,/g')
        
        # Output real-time
        printf "${BLUE}Alt: %6d m${NC} | ${GREEN}Terra: %s s${NC} | ${YELLOW}Dilatato: %s s${NC} | ${RED}Diff: %s ns${NC}\n" \
               $current_altitude "$earth_time_display" "$dilated_time_display" "$time_diff_display"
        
        # Incrementa altitudine e tempo base
        current_altitude=$((current_altitude + ALTITUDE_STEP))
        base_time=$(echo "scale=10; $base_time + 0.1" | bc -l 2>/dev/null)
        
        # Controllo validità
        if [ $? -ne 0 ] || [ -z "$base_time" ]; then
            base_time="0.1"
        fi
        
        # Pausa per visualizzazione
        sleep 0.1
    done
    
    echo -e "${GREEN}[SIM] Simulazione completata. Risultati salvati in: $results_file${NC}"
}

# =============================================================================
# ANALISI RISULTATI
# =============================================================================

analyze_results() {
    local results_file=$1
    
    echo -e "${BLUE}[ANALISI] Elaborazione dati...${NC}"
    
    # Trova file risultati più recente se non specificato
    if [ -z "$results_file" ]; then
        results_file=$(ls -t time_dilation_results_*.csv 2>/dev/null | head -1)
    fi
    
    if [ ! -f "$results_file" ]; then
        echo -e "${RED}[ERROR] File risultati non trovato!${NC}"
        return 1
    fi
    
    # Analisi statistica
    local max_diff=$(tail -n +2 "$results_file" | cut -d',' -f5 | sort -n | tail -1)
    local avg_diff=$(tail -n +2 "$results_file" | cut -d',' -f5 | awk '{sum+=$1} END {if(NR>0) print sum/NR; else print 0}')
    
    # Controlla se i valori sono validi
    if [ -z "$max_diff" ]; then max_diff="0.00"; fi
    if [ -z "$avg_diff" ]; then avg_diff="0.00"; fi
    
    echo -e "${GREEN}=== RISULTATI ANALISI ===${NC}"
    echo -e "Differenza massima: ${YELLOW}$max_diff ns${NC}"
    echo -e "Differenza media: ${YELLOW}$(printf "%.2f" $avg_diff 2>/dev/null || echo $avg_diff) ns${NC}"
    
    # Genera grafico ASCII
    generate_ascii_graph "$results_file"
}

generate_ascii_graph() {
    local file=$1
    local max_val=50  # Scala grafico
    
    echo -e "\n${BLUE}=== GRAFICO DILATAZIONE TEMPORALE ===${NC}"
    echo "Altitudine (km) vs Differenza Temporale (ns)"
    
    tail -n +2 "$file" | while IFS=',' read -r alt earth_time dilated_time quantum_time diff; do
        local alt_km=$((alt / 1000))
        local bar_length=$(echo "scale=0; $diff * $max_val / 100" | bc -l 2>/dev/null)
        
        # Controlla validità
        if [ $? -ne 0 ] || [ -z "$bar_length" ] || [ "$bar_length" -lt 0 ]; then
            bar_length=0
        fi
        
        # Limita lunghezza barra
        if [ "$bar_length" -gt "$max_val" ]; then
            bar_length=$max_val
        fi
        
        # Genera barra
        local bar=""
        for ((i=0; i<bar_length; i++)); do
            bar+="█"
        done
        
        # Visualizza con controllo errori
        printf "%3d km |%-${max_val}s| %s ns\n" $alt_km "$bar" "${diff:-0.00}"
    done
}

# =============================================================================
# MENU PRINCIPALE
# =============================================================================

show_menu() {
    echo -e "\n${GREEN}=== SIMULATORE DILATAZIONE TEMPORALE QUANTISTICA ===${NC}"
    echo -e "${BLUE}1.${NC} Avvia simulazione completa"
    echo -e "${BLUE}2.${NC} Analizza risultati esistenti"
    echo -e "${BLUE}3.${NC} Test connessione FPGA"
    echo -e "${BLUE}4.${NC} Simulazione rapida (10 punti)"
    echo -e "${BLUE}5.${NC} Mostra teoria fisica"
    echo -e "${BLUE}6.${NC} Genera grafico WebGL"
    echo -e "${BLUE}7.${NC} Esci"
    echo -n "Scegli opzione: "
}

quick_simulation() {
    echo -e "${YELLOW}[QUICK] Simulazione rapida...${NC}"
    local original_step=$ALTITUDE_STEP
    local original_max=$MAX_ALTITUDE
    
    ALTITUDE_STEP=10000
    MAX_ALTITUDE=100000
    
    run_time_simulation
    
    ALTITUDE_STEP=$original_step
    MAX_ALTITUDE=$original_max
}

show_theory() {
    echo -e "\n${GREEN}=== TEORIA FISICA ===${NC}"
    echo -e "${BLUE}Dilatazione Gravitazionale:${NC}"
    echo "- Il tempo scorre più lentamente in campi gravitazionali forti"
    echo "- Formula: Δt = t₀ × √(1 - 2GM/rc²)"
    echo "- Allontanandosi dalla Terra, il tempo accelera"
    echo ""
    echo -e "${BLUE}Aspetti Quantistici:${NC}"
    echo "- Tempo di Planck: 5.39×10⁻⁴⁴ secondi"
    echo "- Possibile discretizzazione quantistica del tempo"
    echo "- Il 'presente' come sovrapposizione quantistica"
    echo ""
    echo -e "${BLUE}Implementazione FPGA:${NC}"
    echo "- Calcolo parallelo di dilatazioni temporali"
    echo "- Simulazione real-time di effetti relativistici"
    echo "- Visualizzazione della 'nebbia temporale'"
}

test_fpga() {
    echo -e "${BLUE}[TEST] Verifica connessione FPGA...${NC}"
    init_fpga
    
    if [ "$FPGA_MODE" == "hardware" ]; then
        local test_response=$(send_fpga_command "TEST" 0 1.0)
        echo -e "${GREEN}[TEST] Risposta FPGA: $test_response${NC}"
    else
        echo -e "${YELLOW}[TEST] Modalità simulazione attiva${NC}"
    fi
}

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    # Controlla dipendenze
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}[ERROR] bc non installato. Installa con: pacman -S bc${NC}"
        exit 1
    fi
    
    # Inizializza FPGA
    init_fpga
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                run_time_simulation
                ;;
            2)
                echo -n "File risultati (invio per l'ultimo): "
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
                echo -e "${GREEN}Arrivederci!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opzione non valida!${NC}"
                ;;
        esac
        
        echo -n "Premi INVIO per continuare..."
        read -r
    done
}

# Avvia programma
main "$@"