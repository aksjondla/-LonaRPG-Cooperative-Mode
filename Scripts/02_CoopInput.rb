#==============================================================================
# Cooperative Mode - Input Handler
#==============================================================================
# Captures alternative keyboard inputs for Player 2
# Uses Windows API for key detection
#==============================================================================

module CoopInput
  # Virtual Key codes for Windows (comprehensive list)
  VK_CODES = {
    # Letters A-Z
    A: 0x41, B: 0x42, C: 0x43, D: 0x44, E: 0x45, F: 0x46, G: 0x47, H: 0x48,
    I: 0x49, J: 0x4A, K: 0x4B, L: 0x4C, M: 0x4D, N: 0x4E, O: 0x4F, P: 0x50,
    Q: 0x51, R: 0x52, S: 0x53, T: 0x54, U: 0x55, V: 0x56, W: 0x57, X: 0x58,
    Y: 0x59, Z: 0x5A,
    
    # Numbers 0-9 (top row) - using symbols
    NUM0: 0x30, NUM1: 0x31, NUM2: 0x32, NUM3: 0x33, NUM4: 0x34,
    NUM5: 0x35, NUM6: 0x36, NUM7: 0x37, NUM8: 0x38, NUM9: 0x39,
    
    # Function keys
    F1: 0x70, F2: 0x71, F3: 0x72, F4: 0x73, F5: 0x74, F6: 0x75,
    F7: 0x76, F8: 0x77, F9: 0x78, F10: 0x79, F11: 0x7A, F12: 0x7B,
    
    # Numpad
    NUMPAD0: 0x60, NUMPAD1: 0x61, NUMPAD2: 0x62, NUMPAD3: 0x63, NUMPAD4: 0x64,
    NUMPAD5: 0x65, NUMPAD6: 0x66, NUMPAD7: 0x67, NUMPAD8: 0x68, NUMPAD9: 0x69,
    
    # Special keys
    SPACE: 0x20, ENTER: 0x0D, ESC: 0x1B, TAB: 0x09, BACKSPACE: 0x08,
    SHIFT: 0x10, CTRL: 0x11, ALT: 0x12,
    
    # Arrow keys
    LEFT_ARROW: 0x25, UP_ARROW: 0x26, RIGHT_ARROW: 0x27, DOWN_ARROW: 0x28
  }
  
  # Get VK code for a key symbol
  def self.get_vk_code(key_symbol)
    VK_CODES[key_symbol] || VK_CODES[key_symbol.to_s.to_sym]
  end
  
  # Initialize Windows API
  @@get_async_key_state = nil
  @@use_win32 = false
  @@key_states = {}
  @@prev_states = {}
  @@debug_mode = true
  @@initialized = false
  
  def self.initialize_input
    return if @@initialized
    @@initialized = true
    
    begin
      @@get_async_key_state = Win32API.new('user32', 'GetAsyncKeyState', 'i', 'i')
      @@use_win32 = true
      p "CoopInput: Win32API initialized successfully"
    rescue => e
      @@use_win32 = false
      p "CoopInput: Win32API not available - #{e.message}"
      p "CoopInput: Using fallback input system"
    end
  end
  
  # Update key states each frame
  def self.update
    initialize_input unless @@initialized
    
    if @@use_win32 && @@get_async_key_state

      keys = CoopConfig.keys
      

      keys.each do |action, key_symbol|
        @@prev_states[key_symbol] = @@key_states[key_symbol] || false
        vk_code = get_vk_code(key_symbol)
        if vk_code
          @@key_states[key_symbol] = (@@get_async_key_state.call(vk_code) & 0x8000) != 0
        end
      end
    else
      # Fallback: use game's Input system for toggle
      toggle_key = CoopConfig.keys[:toggle_control]
      @@prev_states[toggle_key] = @@key_states[toggle_key] || false
      @@key_states[toggle_key] = Input.trigger?(:F5)
    end
  rescue => e
    p "CoopInput: Error in update - #{e.message}"
  end
  
  def self.press?(key)
    mapped_key = CoopConfig.keys[key]
    @@key_states[mapped_key] || false
  end
  
  def self.trigger?(key)
    mapped_key = CoopConfig.keys[key]
    current = @@key_states[mapped_key] || false
    previous = @@prev_states[mapped_key] || false
    result = current && !previous
    
    if result && @@debug_mode
      p "CoopInput: #{key} triggered (mapped to #{mapped_key})"
    end
    
    result
  end
  
  def self.repeat?(key)
    press?(key)
  end
  
  def self.get_direction
    return 0 unless CoopConfig.manual_control?
    
    # Vertical takes priority
    return 8 if press?(:up)     # Up
    return 2 if press?(:down)   # Down
    return 4 if press?(:left)   # Left
    return 6 if press?(:right)  # Right
    return 0  # No movement
  end
end
