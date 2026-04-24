#!/bin/bash
# ============================================================
# .bash_profile — Arch Gaming OS
# ============================================================
# Eseguito al login dell'utente 'gamer' su TTY.
# Avvia la sessione Gamescope+Steam SOLO su tty1.
# Su altre TTY (tty2-6) ottieni una shell normale per manutenzione.

if [[ "$(tty)" == "/dev/tty1" ]] && [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then

    # ============================
    # Variabili d'ambiente gaming
    # ============================

    # --- GPU AMD (RADV) ---
    # NOTA: RADV_PERFTEST=gpl NON è più necessario — GPL è abilitato
    # di default in RADV da Mesa 23.1+ (maggio 2023).
    export AMD_VULKAN_ICD=RADV             # Forza RADV come driver (non AMDVLK)
    export MESA_DISK_CACHE_SINGLE_FILE=1   # Shader cache in file singolo

    # --- GPU NVIDIA (decommentare se NVIDIA, commentare sezione AMD) ---
    # export __GLX_VENDOR_LIBRARY_NAME=nvidia
    # export GBM_BACKEND=nvidia-drm
    # export WLR_NO_HARDWARE_CURSORS=1
    # export LIBVA_DRIVER_NAME=nvidia

    # --- Gamescope / Steam ---
    export ENABLE_GAMESCOPE_WSI=1
    export STEAM_GAMESCOPE_HDR=1
    export STEAM_GAMESCOPE_VRR_SUPPORTED=1
    export STEAM_USE_MANGOAPP=1

    # NOTA: DXVK_ASYNC è stato RIMOSSO da DXVK e GE-Proton dal 2023.
    # La compilazione shader asincrona è ora gestita nativamente da GPL
    # (Graphics Pipeline Library), abilitato di default nei driver moderni.
    # NON usare DXVK_ASYNC=1 — è deprecato e può corrompere la shader cache.

    # --- Proton ---
    export PROTON_ENABLE_NVAPI=1           # NVAPI per DLSS (NVIDIA)

    # ============================
    # Lancio sessione Gamescope
    # ============================
    # Modifica -W/-H/-r per il tuo monitor:
    #   -W/-H = risoluzione output (nativa del display)
    #   -w/-h = risoluzione interna (rendering, può essere inferiore per FSR)
    #   -r    = refresh rate target

    exec gamescope \
        -W 1920 -H 1080 \
        -w 1920 -h 1080 \
        -r 144 \
        -f \
        -e \
        --adaptive-sync \
        --force-grab-cursor \
        --xwayland-count 2 \
        -- steam -bigpicture -steampal
    # NOTA su flag Steam:
    #   -bigpicture = lancia in Big Picture Mode (ora è il default)
    #   -steampal   = abilita Steam Deck-like Game Mode UI
    # NON usare -steamos3 -steamdeck su hardware desktop —
    # attivano comportamenti specifici per l'hardware Deck
    # che possono causare problemi su GPU/display diversi.

    # Se Gamescope/Steam termina, il login termina → getty rilancia → autologin → loop.
fi

# Se siamo su tty2+ o in una sessione già grafica, carica il profilo bash normale
[[ -f ~/.bashrc ]] && . ~/.bashrc
