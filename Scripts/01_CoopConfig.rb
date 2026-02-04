#==============================================================================
# Cooperative Mode - Configuration Module
#==============================================================================
# This manages cooperative mode settings and control states
# Loads keybindings from keybindings.json
#==============================================================================

module CoopConfig
  @@enabled = false
  @@control_mode = :ai  # :ai or :manual
  @@keys_loaded = false
  
  # Default key mappings for Player 2 (used if JSON fails to load)
  DEFAULT_KEYS = {
    up: :I,
    down: :K,
    left: :J,
    right: :L,
    skill1: :Y,
    skill2: :NUM6,
    skill3: :NUM5,
    skill4: :NUM4,
    skill5: :NUM7,
    skill6: :NUM8,
    dodge: :NUM3,
    toggle_control: :F2,
    force_enable: :F3,
    cycle_companion: :F4
  }
  
  @@keys = DEFAULT_KEYS.dup
  
  # Load keybindings from JSON file
  def self.load_keybindings
    return if @@keys_loaded
    @@keys_loaded = true
    
    begin
      json_path = defined?(COOP_MOD_ROOT) && COOP_MOD_ROOT ? File.join(COOP_MOD_ROOT, "keybindings.json") : nil
      unless json_path && File.exist?(json_path)
        p "CoopConfig: keybindings.json not found, using defaults"
        return
      end
      json_content = File.read(json_path)
      config = JSON.parse(json_content)
      
      if config["movement"]
        @@keys[:up] = config["movement"]["up"].to_sym if config["movement"]["up"]
        @@keys[:down] = config["movement"]["down"].to_sym if config["movement"]["down"]
        @@keys[:left] = config["movement"]["left"].to_sym if config["movement"]["left"]
        @@keys[:right] = config["movement"]["right"].to_sym if config["movement"]["right"]
      end
      
      if config["combat"]
        @@keys[:skill1] = config["combat"]["skill1"].to_sym if config["combat"]["skill1"]
        @@keys[:skill2] = config["combat"]["skill2"].to_sym if config["combat"]["skill2"]
        @@keys[:skill3] = config["combat"]["skill3"].to_sym if config["combat"]["skill3"]
        @@keys[:skill4] = config["combat"]["skill4"].to_sym if config["combat"]["skill4"]
        @@keys[:skill5] = config["combat"]["skill5"].to_sym if config["combat"]["skill5"]
        @@keys[:skill6] = config["combat"]["skill6"].to_sym if config["combat"]["skill6"]
        @@keys[:dodge] = config["combat"]["dodge"].to_sym if config["combat"]["dodge"]
      end
      
      if config["system"]
        @@keys[:toggle_control] = config["system"]["toggle_control"].to_sym if config["system"]["toggle_control"]
        @@keys[:force_enable] = config["system"]["force_enable"].to_sym if config["system"]["force_enable"]
        @@keys[:cycle_companion] = config["system"]["cycle_companion"].to_sym if config["system"]["cycle_companion"]
      end
      
      p "CoopConfig: Keybindings loaded from keybindings.json"
      
    rescue => e
      p "CoopConfig: Error loading keybindings - #{e.message}"
      p "CoopConfig: Using default keybindings"
      @@keys = DEFAULT_KEYS.dup
    end
  end
  
  def self.keys
    load_keybindings unless @@keys_loaded
    @@keys
  end
  
  
  KEYS = @@keys # compatibility with code from first attempts
  
  def self.enable
    @@enabled = true
    p "CoopMode: Enabled"
  end
  
  def self.disable
    @@enabled = false
    @@control_mode = :ai
    p "CoopMode: Disabled"
  end
  
  def self.enabled?
    @@enabled
  end
  
  def self.set_control_mode(mode)
    @@control_mode = mode
    p "Companion control mode: #{mode}"
  end
  
  def self.manual_control?
    @@enabled && @@control_mode == :manual
  end
  
  def self.toggle_control_mode
    if @@control_mode == :ai
      @@control_mode = :manual
      p "Player 2 now controls the companion"
      show_control_message(CoopTranslations.t(:ready_player2))
    else
      @@control_mode = :ai
      p "Companion returns to AI control"
      show_control_message(CoopTranslations.t(:player2_off))
    end
  end
  
  def self.show_control_message(text)
    begin
      return unless $game_map && $game_map.interpreter
      
      # Show popup message
      $game_map.interpreter.call_msg_popup(text) if $game_map.interpreter.respond_to?(:call_msg_popup)
      
      # Show balloon over player 1
      $game_player.call_balloon(0) if $game_player && $game_player.respond_to?(:call_balloon)
    rescue => e
      p "CoopConfig: Error showing message - #{e.message}"
    end
  end
  
  def self.get_control_mode
    @@control_mode
  end
end
